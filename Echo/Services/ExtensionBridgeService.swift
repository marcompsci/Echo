import Foundation
import Combine
import SwiftUI

// Bridges the Safari Web Extension and the main app via a shared App Group container.
// JS → SafariWebExtensionHandler → UserDefaults(group) + Darwin notification → here.
final class ExtensionBridgeService: ObservableObject {
    static let shared = ExtensionBridgeService()

    @Published var lastSnapshot: ElementSnapshot?
    @Published var connectionStatus: ConnectionStatus = .idle
    @Published var currentPageURL: String = ""
    @Published var currentPageTitle: String = ""
    @Published var pendingVoiceCommand: String?

    enum ConnectionStatus {
        case idle, receiving, processing, ready
        var label: String {
            switch self {
            case .idle:       return "Waiting for Safari extension"
            case .receiving:  return "Element received"
            case .processing: return "Analyzing..."
            case .ready:      return "Analysis ready"
            }
        }
        var color: Color {
            switch self {
            case .idle:       return .secondary
            case .receiving:  return .blue
            case .processing: return .orange
            case .ready:      return .green
            }
        }
    }

    private let appGroupID = "group.com.echo.extension"
    private var defaults: UserDefaults?
    private let nlService = NLAnalysisService.shared
    var onSnapshotReceived: ((ElementSnapshot) -> Void)?

    private init() {
        defaults = UserDefaults(suiteName: appGroupID)
        registerDarwinObservers()
    }

    // MARK: - Darwin Notification Bridge

    private func registerDarwinObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        let elementCallback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let bridge = Unmanaged<ExtensionBridgeService>.fromOpaque(observer).takeUnretainedValue()
            bridge.handleElementNotification()
        }

        let voiceCallback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let bridge = Unmanaged<ExtensionBridgeService>.fromOpaque(observer).takeUnretainedValue()
            bridge.handleVoiceCommandNotification()
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            center, selfPtr, elementCallback,
            "com.echo.elementSelected" as CFString,
            nil, .deliverImmediately
        )

        CFNotificationCenterAddObserver(
            center, selfPtr, voiceCallback,
            "com.echo.voiceCommand" as CFString,
            nil, .deliverImmediately
        )
    }

    private func handleElementNotification() {
        guard let raw = defaults?.dictionary(forKey: "lastInspectedElement") else { return }
        DispatchQueue.main.async { self.connectionStatus = .receiving }
        processElementData(raw)
    }

    private func handleVoiceCommandNotification() {
        guard let command = defaults?.string(forKey: "pendingVoiceCommand") else { return }
        DispatchQueue.main.async {
            self.pendingVoiceCommand = command
        }
    }

    // MARK: - Element Processing

    func processElementData(_ raw: [String: Any]) {
        DispatchQueue.main.async { self.connectionStatus = .processing }

        let snapshot = ElementSnapshot(
            tagName:    raw["tagName"]   as? String ?? "unknown",
            elementId:  raw["id"]        as? String ?? "",
            className:  raw["className"] as? String ?? "",
            innerText:  raw["innerText"] as? String ?? "",
            outerHTML:  raw["outerHTML"] as? String ?? "",
            xpath:      raw["xpath"]     as? String ?? "",
            pageURL:    raw["pageURL"]   as? String ?? "",
            pageTitle:  raw["pageTitle"] as? String ?? ""
        )

        if let css = raw["computedCSS"] as? [String: String] { snapshot.computedCSS = css }
        if let attrs = raw["attributes"] as? [String: String] { snapshot.attributes = attrs }

        DispatchQueue.global(qos: .userInitiated).async {
            self.nlService.analyze(snapshot: snapshot)
            DispatchQueue.main.async {
                self.lastSnapshot = snapshot
                self.currentPageURL = snapshot.pageURL
                self.currentPageTitle = snapshot.pageTitle
                self.connectionStatus = .ready
                self.onSnapshotReceived?(snapshot)
            }
        }
    }

    // MARK: - Simulate (for testing without extension)

    func simulateElementSelection() {
        let mockData: [String: Any] = [
            "tagName":   "BUTTON",
            "id":        "submit-btn",
            "className": "btn btn-primary action-button",
            "innerText": "",
            "outerHTML": "<button id=\"submit-btn\" class=\"btn btn-primary action-button\" style=\"color:red\"></button>",
            "xpath":     "//body/main/form/div[2]/button[1]",
            "pageURL":   "https://example.com/checkout",
            "pageTitle": "Checkout — Example Store",
            "computedCSS": ["display": "inline-flex", "color": "rgb(255,255,255)", "background-color": "rgb(79,70,229)"],
            "attributes": ["type": "submit", "data-action": "checkout"]
        ]
        processElementData(mockData)
    }
}
