import SafariServices
import os.log

// Bridges JS ↔ main Echo app via a shared App Group UserDefaults + Darwin notifications.
// JS: browser.runtime.sendNativeMessage("com.echo.extension", msg) → this handler → main app.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: "com.echo.extension", category: "SafariExtension")
    private let appGroupID = "group.com.echo.extension"

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = item?.userInfo?[SFExtensionMessageKey]
        } else {
            message = item?.userInfo?["message"]
        }

        guard let dict = message as? [String: Any], let type = dict["type"] as? String else {
            logger.warning("Received unrecognised message format")
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        logger.debug("Extension message: \(type)")

        switch type {
        case "ELEMENT_SELECTED": handleElementSelected(dict, context: context)
        case "STATUS_REQUEST":   handleStatusRequest(context: context)
        case "VOICE_COMMAND":    handleVoiceCommand(dict, context: context)
        default:
            respond(["type": "UNKNOWN", "received": type], to: context)
        }
    }

    // MARK: - Handlers

    private func handleElementSelected(_ msg: [String: Any], context: NSExtensionContext) {
        guard let data = msg["data"] as? [String: Any] else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(data, forKey: "lastInspectedElement")
        defaults?.set(Date().timeIntervalSince1970, forKey: "lastInspectedTime")
        postDarwin("com.echo.elementSelected")
        respond(["type": "ACK", "status": "received"], to: context)
    }

    private func handleStatusRequest(context: NSExtensionContext) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let lastPing = defaults?.double(forKey: "appHeartbeat") ?? 0
        let appAlive = Date().timeIntervalSince1970 - lastPing < 30
        respond(["type": "STATUS", "nativeConnected": appAlive, "version": "1.0"], to: context)
    }

    private func handleVoiceCommand(_ msg: [String: Any], context: NSExtensionContext) {
        guard let command = msg["command"] as? String else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(command, forKey: "pendingVoiceCommand")
        postDarwin("com.echo.voiceCommand")
        respond(["type": "ACK"], to: context)
    }

    // MARK: - Helpers

    private func respond(_ payload: [String: Any], to context: NSExtensionContext) {
        let item = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            item.userInfo = [SFExtensionMessageKey: payload]
        } else {
            item.userInfo = ["message": payload]
        }
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func postDarwin(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }
}
