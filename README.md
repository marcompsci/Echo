# Echo — AI Visual Guide (MVP)

> See it clearly. Know what to do.

Echo is a privacy-first iOS app that helps people understand what they are looking at on their phone. A user intentionally imports or shares a screenshot or photo, asks Echo a question by typing or holding a voice button, and receives a concise explanation with numbered visual annotations and practical next steps.

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 16+ |
| iOS deployment target | 18.0 |
| Swift | 6 |
| SwiftData | iOS 17+ (bundled) |

---

## Setup & Run

1. **Clone / open the project**
   ```
   open Echo.xcodeproj
   ```

2. **Sign the main target**
   - Select the **Echo** target → Signing & Capabilities → choose your Team.
   - The extension targets (Widget, iMessage, Safari) each need their own provisioning profile or can be deleted if unused in development.

3. **Run on Simulator or device**
   - Select the **Echo** scheme and an iOS 18 simulator or device.
   - Press ⌘R.

4. **First launch**
   - A 3-page onboarding flow appears on first launch only.
   - Completion is stored in `AppStorage("hasSeenOnboarding")`.
   - To replay onboarding: delete the app from the simulator.

5. **Mock mode**
   - The app ships with `MockGuideService`, which returns deterministic sample data after ~1.8 s.
   - No backend or API key is required to run the full feature flow.

---

## Architecture

```
Echo/
  App/             AppRouter (NavigationStack state)
  DesignSystem/    Colors, Typography, Spacing constants
  Models/          EchoSession (SwiftData), GuideResponse, Annotation, …
  Services/        GuideService protocol, MockGuideService, APIClient scaffold, …
  ViewModels/      @Observable @MainActor classes (Home, Analyze, Result, Settings)
  Views/           Onboarding, Home, Analyze, Result, Settings, Components
  Intents/         AskEchoIntent + EchoShortcuts (Siri / Shortcuts app)
```

- **MVVM** — ViewModels are `@Observable` `@MainActor` classes.
- **SwiftData** — `EchoSession` stores question, summary, and (optionally) image data.
- **Navigation** — single `NavigationStack` owned by `AppRouter`.
- **Services** — injected via initializer; `MockGuideService` is the default.

---

## Replacing MockGuideService

The service boundary is the `GuideService` protocol:

```swift
protocol GuideService: Sendable {
    func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse
}
```

To activate a live backend:

1. Implement `LiveGuideService: GuideService` (scaffold in `APIClient.swift`).
2. Inject it in `AnalyzeViewModel.init(guideService:)`.
3. **Never embed provider API keys in the app.** All model-provider credentials must live on the server.

### Server requirements (before shipping)

| Requirement | Notes |
|-------------|-------|
| Server-side auth | Issue short-lived tokens; rotate regularly |
| Rate limiting | Per-user and global caps |
| Content filtering | Server-side moderation before sending to AI model |
| Encrypted transport | TLS 1.3 minimum |
| Deletion controls | Honor user delete requests end-to-end |
| Audit logging | Log request metadata; **never** log raw image content |

---

## Required Info.plist keys

| Key | Reason |
|-----|--------|
| `NSMicrophoneUsageDescription` | Push-to-talk voice button in AnalyzeView requests microphone only on first press |
| `NSSpeechRecognitionUsageDescription` | SFSpeechRecognizer converts held-button audio to text |
| `CFBundleURLTypes` (`echo://`) | Receives the `echo://import` URL from the future Share Extension |

**PhotosPicker** uses the system-provided image picker, which does **not** require `NSPhotoLibraryUsageDescription` because the user picks photos through the system UI with no persistent library access granted to the app.

---

## Testing Siri Shortcuts

1. Build and run on a **real device** (Shortcuts are not available in Simulator).
2. Open the **Shortcuts** app → tap **+** → search "Echo".
3. You should see **Ask Echo** in the action list.
4. Add it and run it — Echo opens to the home screen.
5. With Siri: say **"Ask Echo"**, **"Open Echo"**, or **"Get help from Echo"**.

---

## Running Unit Tests

```
⌘U  (or Product → Test)
```

Key test suites (in `EchoTests/`):

| File | Coverage |
|------|---------|
| `GuideResponseTests.swift` | JSON decoding, round-trip, MockGuideService determinism |
| `AnnotationRendererTests.swift` | Coordinate conversion, Codable enums, retention policy |

---

## Next Build Steps

1. **Add the real backend** — implement `LiveGuideService`, configure server auth and rate limits.
2. **Add the Share Extension** — follow `ShareExtensionSetup.md` to let users share images directly from any app.
3. **Add authenticated accounts** — user identity, cloud guide sync, cross-device deletion.
4. **Add usage limits and StoreKit subscription** — gate advanced features; respect App Store guidelines.
5. **Conduct TestFlight usability testing before expanding automation** — observe real users before adding Siri automation or proactive suggestions.
