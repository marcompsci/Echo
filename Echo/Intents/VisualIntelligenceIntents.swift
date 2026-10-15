// VisualIntelligence isn't in every SDK (e.g. some Simulator runtimes),
// so this whole integration compiles only where the framework exists.
#if canImport(VisualIntelligence)
import AppIntents
import VisualIntelligence
import VideoToolbox
import CoreGraphics

// MARK: - Visual Intelligence integration (Apple Intelligence)
//
// When someone screenshots their iPhone (or points the camera) and opens
// Visual Intelligence, Echo appears as a result: "Ask Echo about this".
// Tapping it opens Echo with that exact screen, ready for a question.
// This is how Echo "sees any screen" on iPhone without a screen recorder.

struct EchoScreenEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Echo Guide"
    static let defaultQuery = EchoScreenEntityQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Ask Echo about this",
            subtitle: "Step-by-step help with what's on your screen",
            image: .init(systemName: "sparkles")
        )
    }
}

struct EchoScreenEntityQuery: EntityQuery {
    func entities(for identifiers: [EchoScreenEntity.ID]) async throws -> [EchoScreenEntity] {
        identifiers.filter { ScreenCaptureStore.exists($0) }.map { EchoScreenEntity(id: $0) }
    }
}

/// Receives the screen from Visual Intelligence.
struct EchoVisualIntelligenceQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [EchoScreenEntity] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }
        var cgImage: CGImage?
        _ = pixelBuffer.withUnsafeBuffer { buffer in
            VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
        }
        guard let cgImage, let id = ScreenCaptureStore.save(cgImage) else { return [] }
        return [EchoScreenEntity(id: id)]
    }
}

/// Runs when the person taps Echo's result in Visual Intelligence.
struct OpenEchoScreenIntent: OpenIntent {
    static let title: LocalizedStringResource = "Ask Echo About This"

    @Parameter(title: "Screen")
    var target: EchoScreenEntity

    func perform() async throws -> some IntentResult {
        await EchoLaunchCenter.shared.request(.capturedScreen(id: target.id))
        return .result()
    }
}
#endif
