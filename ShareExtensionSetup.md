# Share Extension Setup Guide

This document explains how to add a Share Extension target so users can share images into Echo from any app (Safari, Photos, Files, etc.).

The main app target already includes `SharedImageInbox` (in `Services/SharedImageInbox.swift`) which is ready to consume images deposited by the extension.

---

## Step 1 — Add the Share Extension target

1. In Xcode, go to **File → New → Target**.
2. Select **Share Extension** under the iOS platform.
3. Name it **EchoShare**.
4. Ensure "Embed in Application" is set to **Echo**.
5. Click **Finish**.

---

## Step 2 — Configure supported content types

Edit `EchoShare/Info.plist`. Replace the default `NSExtensionActivationRule` with a predicate that accepts images only:

```xml
<key>NSExtensionAttributes</key>
<dict>
    <key>NSExtensionActivationRule</key>
    <string>SUBQUERY (
        extensionItems,
        $extensionItem,
        SUBQUERY (
            $extensionItem.attachments,
            $attachment,
            (
                UTI-CONFORMS-TO($attachment.registeredTypeIdentifiers, "public.image")
            )
        ).@count == 1
    ).@count == 1</string>
</dict>
```

---

## Step 3 — Set up a shared App Group

App Groups let the extension and main app share a file system container.

1. Select the **Echo** target → **Signing & Capabilities → + Capability → App Groups**.
2. Add the group: `group.com.yourcompany.echo` (replace with your real bundle ID prefix).
3. Repeat for the **EchoShare** target.

---

## Step 4 — Save the incoming image in the extension

In `EchoShare/ShareViewController.swift`, implement `didSelectPost()`:

```swift
import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    private let appGroupID = "group.com.yourcompany.echo"
    private let filename  = "pending_share.jpg"

    override func didSelectPost() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
              }) else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] result, _ in
            guard let self else { return }
            var imageData: Data?

            if let url = result as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let image = result as? UIImage {
                imageData = image.jpegData(compressionQuality: 0.85)
            }

            if let data = imageData,
               let container = FileManager.default.containerURL(
                   forSecurityApplicationGroupIdentifier: self.appGroupID
               ) {
                let dest = container.appendingPathComponent(self.filename)
                try? data.write(to: dest)
            }

            self.extensionContext?.completeRequest(returningItems: [], completionHandler: { _ in
                self.openMainApp()
            })
        }
    }

    private func openMainApp() {
        guard let url = URL(string: "echo://import") else { return }
        // Open via the responder chain (required in extensions)
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url)
                return
            }
            responder = r.next
        }
    }

    override func isContentValid() -> Bool { true }
    override func configurationItems() -> [Any] { [] }
}
```

---

## Step 5 — Consume the image in the main app

`SharedImageInbox` (already in the main target) handles this automatically.

In `EchoApp.swift`, the `onOpenURL` handler calls:

```swift
let inbox = SharedImageInbox()
if let data = inbox.consumePendingImage() {
    router.navigateToAnalyze(imageData: data)
}
```

The inbox reads the file from the shared container and deletes it after consumption.

---

## Identifiers (replace before shipping)

| Placeholder | Replace with |
|-------------|-------------|
| `group.com.yourcompany.echo` | Your actual App Group ID |
| `echo://import` | Your actual URL scheme (already registered in Info.plist) |

---

## Privacy note

The Share Extension receives only the image the user explicitly selects from the share sheet. It does not access any other photos, files, or data. The image is written to the shared container and immediately consumed by the main app; it is not retained by the extension itself.
