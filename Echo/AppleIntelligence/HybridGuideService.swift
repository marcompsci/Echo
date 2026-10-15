import Foundation

// MARK: - Guide engine routing (like Clicky's automatic model routing)
//
//   .automatic  → Claude (sees icons, best pointing). If the cloud is down or
//                 offline, falls back to Apple Intelligence on-device.
//   .onDevice   → Apple Intelligence only. Private, free, offline.
//   .cloud      → Claude only.

enum GuideEngine: String, CaseIterable, Identifiable {
    case automatic, onDevice, cloud
    var id: String { rawValue }

    static let storageKey = "guideEngine"

    static var current: GuideEngine {
        GuideEngine(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .automatic
    }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .onDevice:  return "On-device (Apple Intelligence)"
        case .cloud:     return "Cloud (Claude)"
        }
    }

    var detail: String {
        switch self {
        case .automatic: return "Best answers. Uses Apple Intelligence if the cloud can't be reached."
        case .onDevice:  return "Nothing leaves your iPhone. Reads screen text only, so it can't point at icons."
        case .cloud:     return "Sends the screenshot to Echo's cloud guide. Can point at icons and images."
        }
    }
}

struct HybridGuideService: GuideService {
    private let cloud: (any GuideService)?
    private let onDevice: any GuideService

    init(cloud: (any GuideService)?, onDevice: any GuideService = OnDeviceGuideService()) {
        self.cloud = cloud
        self.onDevice = onDevice
    }

    func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse {
        DevInspector.shared.noteShield([])
        let hasContext = !EchoPersonalContext.text().isEmpty
        let start = ContinuousClock.now
        do {
            let (response, engineName) = try await route(imageData: imageData, userQuestion: userQuestion)
            DevInspector.shared.record(DevTrace(
                feature: "Guide", engine: engineName, input: userQuestion,
                outcome: "\(response.steps.count) steps · \(response.summary.prefix(80))",
                latencyMs: DevInspector.milliseconds(since: start), succeeded: true,
                hidden: DevInspector.shared.lastHidden.map(\.label),
                payloadBytes: imageData.count, usedPersonalContext: hasContext))
            return response
        } catch {
            DevInspector.shared.record(DevTrace(
                feature: "Guide", engine: GuideEngine.current.title, input: userQuestion,
                outcome: "Error: \(error.localizedDescription)",
                latencyMs: DevInspector.milliseconds(since: start), succeeded: false,
                payloadBytes: imageData.count, usedPersonalContext: hasContext))
            throw error
        }
    }

    private func route(imageData: Data, userQuestion: String) async throws -> (GuideResponse, String) {
        let engine = GuideEngine.current

        if engine == .onDevice || cloud == nil {
            return (try await onDevice.createGuide(imageData: imageData, userQuestion: userQuestion), "Apple Intelligence")
        }

        guard let cloud else { throw EchoError.analysisUnavailable }
        do {
            return (try await cloud.createGuide(imageData: imageData, userQuestion: userQuestion), "Claude")
        } catch {
            guard engine == .automatic, AppleIntelligence.isAvailable else { throw error }
            if let echoError = error as? EchoError, case .imageProcessingFailed = echoError { throw error }
            return (try await onDevice.createGuide(imageData: imageData, userQuestion: userQuestion), "Apple Intelligence (fallback)")
        }
    }
}
