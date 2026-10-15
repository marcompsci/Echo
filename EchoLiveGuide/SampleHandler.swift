import ReplayKit
import CoreImage
import CoreMedia
import ImageIO

// MARK: - Echo Live Guide (Broadcast Upload Extension)
//
// The iPhone version of Clicky "seeing your screen". While the person shares
// their screen with Echo (Control Center → Screen Recording → Echo, or the
// button in Echo's Live Guide screen), iOS streams frames here — from ANY app.
//
// Loop:  frame → has the screen changed and settled? → ask the guide service
//        "what's the next step toward <goal> on this screen?" → banner + voice.
//
// Kept lean on purpose: broadcast extensions have a ~50 MB memory limit, so we
// look at ~1–2 frames a second, shrink them, and keep nothing but the latest.

final class SampleHandler: RPBroadcastSampleHandler {

    // Tuning
    private let sampleInterval: CFTimeInterval = 0.6      // how often to look at a frame
    private let settleTime: CFTimeInterval = 0.9          // screen must be still this long
    private let minTimeBetweenCalls: CFTimeInterval = 2.5 // don't spam the guide service
    private let changeThreshold: Double = 5.0             // avg brightness diff (0–255) that counts as "changed"
    private let maxUploadEdge: CGFloat = 1024

    private let ciContext = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: false])
    private let lock = NSLock()

    // State (guarded by lock)
    private var goal = ""
    private var client: LiveCoachClient?
    private var notifier: LiveGuideNotifier?
    private var history: [String] = []
    private var lastSampleTime: CFTimeInterval = 0
    private var lastFingerprint: [UInt8]?
    private var lastChangeTime: CFTimeInterval = 0
    private var analyzedFingerprint: [UInt8]?
    private var lastCallTime: CFTimeInterval = 0
    private var requestInFlight = false
    private var finished = false
    private var consecutiveErrors = 0

    // MARK: - Broadcast lifecycle

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        guard var session = LiveGuideStore.load(),
              !session.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let client = LiveCoachClient(liveSession: session) else {
            finishBroadcastWithError(NSError(domain: "Echo", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Open Echo, tell it what you want help with, then start Live Guide."
            ]))
            return
        }

        session.status = .watching
        session.steps = []
        session.message = nil
        session.safetyNotice = nil
        session.startedAt = Date()
        LiveGuideStore.save(session)

        let notifier = LiveGuideNotifier(speakAloud: session.speakAloud)
        lock.withLock {
            self.goal = session.goal
            self.client = client
            self.notifier = notifier
        }
        notifier.show(
            title: "Echo is watching",
            body: "Go to the app you need help with. I'll guide you to: \(session.goal)",
            speak: "Okay. Go to the app you need help with, and I'll walk you through it."
        )
    }

    override func broadcastFinished() {
        lock.withLock { finished = true }
        LiveGuideStore.update { session in
            if session.status != .done { session.status = .ended }
        }
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}

    // MARK: - Frames

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = CACurrentMediaTime()

        let shouldSample: Bool = lock.withLock {
            guard !finished, now - lastSampleTime >= sampleInterval else { return false }
            lastSampleTime = now
            return true
        }
        guard shouldSample, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var image = CIImage(cvPixelBuffer: pixelBuffer)
        if let orientation = Self.orientation(of: sampleBuffer) {
            image = image.oriented(orientation)
        }
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))

        guard let fingerprint = fingerprint(of: image) else { return }

        // Decide whether this settled screen is new enough to analyze.
        let shouldAnalyze: Bool = lock.withLock {
            if let last = lastFingerprint, Self.difference(last, fingerprint) > changeThreshold {
                lastFingerprint = fingerprint
                lastChangeTime = now
                return false            // still changing — wait for it to settle
            }
            if lastFingerprint == nil {
                lastFingerprint = fingerprint
                lastChangeTime = now
                return false
            }
            guard !requestInFlight,
                  now - lastChangeTime >= settleTime,
                  now - lastCallTime >= minTimeBetweenCalls else { return false }
            if let analyzed = analyzedFingerprint, Self.difference(analyzed, fingerprint) <= changeThreshold {
                return false            // already gave advice for this screen
            }
            requestInFlight = true
            analyzedFingerprint = fingerprint
            lastCallTime = now
            return true
        }
        guard shouldAnalyze else { return }

        guard let (jpeg, size) = uploadJPEG(from: image) else {
            lock.withLock { requestInFlight = false }
            return
        }
        Task { await analyze(jpeg: jpeg, size: size) }
    }

    // MARK: - Guidance

    private func analyze(jpeg: Data, size: CGSize) async {
        let (client, goal, history, notifier) = lock.withLock { (self.client, self.goal, self.history, self.notifier) }
        guard let client else { return }

        LiveGuideStore.update { $0.status = .thinking }
        defer { lock.withLock { requestInFlight = false } }

        do {
            // Privacy Shield: hide card numbers, passwords, SSNs, keys before upload.
            let safe = PrivacyShield.protect(jpeg: jpeg)
            let reply = try await client.nextStep(
                goal: goal, history: history, jpeg: safe.data,
                width: Int(size.width), height: Int(size.height)
            )
            lock.withLock { consecutiveErrors = 0 }
            handle(reply, notifier: notifier)
        } catch {
            let errors = lock.withLock { () -> Int in consecutiveErrors += 1; return consecutiveErrors }
            LiveGuideStore.update {
                $0.status = .error
                $0.message = "Echo can't reach its guide service right now."
            }
            if errors == 2 {
                notifier?.show(title: "Echo is having trouble",
                               body: "I can't reach my guide service. Check your connection.",
                               speak: nil)
            }
        }
    }

    private func handle(_ reply: LiveCoachReply, notifier: LiveGuideNotifier?) {
        let instruction = reply.instruction.trimmingCharacters(in: .whitespacesAndNewlines)

        switch reply.status {
        case .waiting:
            LiveGuideStore.update { $0.status = .watching }
            return

        case .done:
            LiveGuideStore.update {
                $0.status = .done
                $0.steps.append(LiveGuideStep(instruction: instruction.isEmpty ? "All done!" : instruction, detail: reply.detail))
            }
            notifier?.show(title: "Done ✓", body: instruction.isEmpty ? "You did it." : instruction,
                           speak: instruction.isEmpty ? "You did it." : instruction)
            lock.withLock { finished = true }
            return

        case .nextStep, .wrongScreen:
            guard !instruction.isEmpty else { return }
            let isRepeat = lock.withLock { () -> Bool in
                if history.last?.caseInsensitiveCompare(instruction) == .orderedSame { return true }
                history.append(instruction)
                return false
            }
            let stepNumber = LiveGuideStore.update { session in
                session.status = .watching
                session.message = nil
                session.safetyNotice = reply.safetyNotice
                if !isRepeat {
                    session.steps.append(LiveGuideStep(instruction: instruction, detail: reply.detail))
                }
            }?.steps.count ?? 1
            guard !isRepeat else { return }

            var body = instruction
            if !reply.detail.isEmpty { body += "\n" + reply.detail }
            if let notice = reply.safetyNotice, !notice.isEmpty { body = "⚠️ \(notice)\n" + body }
            let spoken = [reply.safetyNotice, instruction].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
            notifier?.show(title: "Step \(stepNumber)", body: body, speak: spoken)
        }
    }

    // MARK: - Image helpers

    private static func orientation(of sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation? {
        guard let value = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber
        else { return nil }
        return CGImagePropertyOrientation(rawValue: value.uint32Value)
    }

    /// 24×48 grayscale thumbnail used to tell whether the screen changed.
    private func fingerprint(of image: CIImage) -> [UInt8]? {
        let w = 24, h = 48
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let small = image.transformed(by: CGAffineTransform(scaleX: CGFloat(w) / extent.width,
                                                            y: CGFloat(h) / extent.height))
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        ciContext.render(small, toBitmap: &rgba, rowBytes: w * 4,
                         bounds: CGRect(x: 0, y: 0, width: w, height: h),
                         format: .RGBA8, colorSpace: nil)
        var gray = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let r = Int(rgba[i * 4]), g = Int(rgba[i * 4 + 1]), b = Int(rgba[i * 4 + 2])
            gray[i] = UInt8((r * 299 + g * 587 + b * 114) / 1000)
        }
        return gray
    }

    static func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return .infinity }
        var total = 0
        for i in 0..<a.count { total += abs(Int(a[i]) - Int(b[i])) }
        return Double(total) / Double(a.count)
    }

    private func uploadJPEG(from image: CIImage) -> (Data, CGSize)? {
        let extent = image.extent
        let scale = min(1, maxUploadEdge / max(extent.width, extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let options: [CIImageRepresentationOption: Any] = [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6
        ]
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let data = ciContext.jpegRepresentation(of: scaled, colorSpace: colorSpace, options: options)
        else { return nil }
        return (data, scaled.extent.size)
    }
}
