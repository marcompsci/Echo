import SafariServices
import os.log

// Native message handler for the Echo Safari Web Extension.
// JS → browser.runtime.sendNativeMessage → this handler → shared App Group UserDefaults → main app.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.echo", category: "Extension")
    private let appGroupID = "group.com.echo.extension"

    func beginRequest(with context: NSExtensionContext) {
        guard
            let item = context.inputItems.first as? NSExtensionItem,
            let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any],
            let type = message["type"] as? String
        else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        logger.debug("Extension received: \(type)")

        switch type {
        case "ELEMENT_SELECTED":  handleElementSelected(message, context: context)
        case "STATUS_REQUEST":    handleStatusRequest(context: context)
        case "VOICE_COMMAND":     handleVoiceCommand(message, context: context)
        default:
            respond(["type": "UNKNOWN", "received": type], to: context)
        }
    }

    // MARK: - Handlers

    private func handleElementSelected(_ message: [String: Any], context: NSExtensionContext) {
        guard let data = message["data"] as? [String: Any] else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(data, forKey: "lastInspectedElement")
        defaults?.set(Date().timeIntervalSince1970, forKey: "lastInspectedTime")

        postDarwinNotification(name: "com.echo.elementSelected")
        respond(["type": "ACK", "status": "received"], to: context)
    }

    private func handleStatusRequest(context: NSExtensionContext) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let lastPing = defaults?.double(forKey: "appHeartbeat") ?? 0
        let appAlive = Date().timeIntervalSince1970 - lastPing < 30

        respond([
            "type": "STATUS",
            "nativeConnected": appAlive,
            "version": "1.0"
        ], to: context)
    }

    private func handleVoiceCommand(_ message: [String: Any], context: NSExtensionContext) {
        guard let command = message["command"] as? String else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(command, forKey: "pendingVoiceCommand")

        postDarwinNotification(name: "com.echo.voiceCommand")
        respond(["type": "ACK"], to: context)
    }

    // MARK: - Helpers

    private func respond(_ payload: [String: Any], to context: NSExtensionContext) {
        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: payload]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func postDarwinNotification(name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }
}
