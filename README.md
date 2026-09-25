# Echo ◈

**Echo** is an iOS/macOS app paired with a Safari Web Extension that combines visual element debugging with voice-driven, screen-aware guidance — all powered by on-device Apple Intelligence frameworks.

---

## Overview

Echo gives developers and power users two superpowers in Safari:

1. **Visual Element Inspector** — Click any element on any webpage to extract its HTML, computed CSS, XPath, and attributes. Powered by a Safari Web Extension that injects a non-intrusive overlay into the page.
2. **Voice-Driven Guidance** — Speak commands to receive real-time spoken analysis of selected elements. Echo narrates accessibility issues, naming convention problems, and improvement suggestions hands-free.

All analysis runs entirely on-device using Apple's Natural Language framework — no external API calls, no data leaves your device.

---

## Features

| Feature | Description |
|---|---|
| ◈ Element Picker | Hover to highlight, click to inspect any DOM element |
| 🧠 On-Device NL Analysis | Accessibility checks, pattern detection, naming conventions via `NaturalLanguage` framework |
| 🎙 Voice Guidance | Speak commands (`analyze`, `fix`, `explain`, `suggest`) — Echo responds with AVSpeechSynthesizer |
| 📋 Inspection History | All sessions and snapshots persisted with SwiftData |
| 🔗 Live Bridge | Darwin notifications + App Group shared container connect the extension to the app in real time |
| 🌐 Safari Extension | Works on every webpage, iOS and macOS, via a WebExtension Manifest V3 extension |
| 🔌 Widget + iMessage | WidgetKit and iMessage extension targets included |

---

## Architecture

```
Safari page
  └── content.js          ← element picker overlay, voice guidance banner
        │
  background.js           ← service worker, routes messages
        │
  SafariWebExtensionHandler.swift   ← native bridge (NSExtensionRequestHandling)
        │
  App Group UserDefaults + Darwin notifications
        │
  ExtensionBridgeService  ← receives element data in real time
        │
  NLAnalysisService       ← on-device NL framework analysis
        │
  VoiceGuidanceService    ← AVSpeechSynthesizer + SFSpeechRecognizer
        │
  SwiftUI Views           ← Inspector · Guide · History · Settings tabs
```

---

## Project Structure

```
Echo/
├── Echo/                          # Main iOS/macOS SwiftUI app
│   ├── Models/
│   │   ├── DebugSession.swift     # SwiftData model for inspection sessions
│   │   ├── ElementSnapshot.swift  # Captured element with AI analysis fields
│   │   └── VoiceCommandRecord.swift
│   ├── Services/
│   │   ├── ExtensionBridgeService.swift   # Darwin notification bridge
│   │   ├── NLAnalysisService.swift        # Natural Language framework analysis
│   │   └── VoiceGuidanceService.swift     # Speech synthesis + recognition
│   ├── Views/
│   │   ├── InspectorView.swift    # Live element card + AI insight panels
│   │   ├── VoiceGuidanceView.swift # Mic button, waveform, 4 guidance modes
│   │   ├── ElementDetailView.swift # HTML / CSS / Attributes tabs
│   │   ├── HistoryView.swift       # Past sessions + search
│   │   └── SettingsView.swift      # Voice, analysis, and appearance config
│   ├── EchoApp.swift
│   └── ContentView.swift          # 4-tab root view
│
├── EchoSafariExtension/           # Safari Web Extension target
│   ├── SafariWebExtensionHandler.swift
│   └── Resources/
│       ├── manifest.json          # WebExtension Manifest V3
│       ├── content.js             # Element picker + overlay UI
│       ├── background.js          # Service worker + native messaging
│       ├── popup.html/js/css      # Toolbar popup
│       └── _locales/en/messages.json
│
├── EchoWidgetExtension/           # WidgetKit widget
└── EchoiMessageExtension/         # iMessage extension
```

---

## Apple Frameworks Used

| Framework | Usage |
|---|---|
| `NaturalLanguage` | On-device element classification, language detection, naming convention analysis, accessibility auditing |
| `AVFoundation` | `AVSpeechSynthesizer` for text-to-speech guidance |
| `Speech` | `SFSpeechRecognizer` + `AVAudioEngine` for voice command input |
| `SafariServices` | `NSExtensionRequestHandling` native message bridge |
| `SwiftData` | Persistent storage for sessions, snapshots, and voice command history |
| `WidgetKit` | Home screen widget |

---

## Setup

### Requirements
- Xcode 15+
- iOS 16+ / macOS 13+
- Apple Developer account (for Safari extension and App Group entitlements)

### Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/marcompsci/Echo.git
   cd Echo
   open Echo.xcodeproj
   ```

2. **Configure App Group** in Xcode for both the `Echo` and `EchoSafariExtension` targets:
   - Target → Signing & Capabilities → `+` → App Groups → `group.com.echo.extension`

3. **Enable the extension** on device or simulator:
   - iOS: Settings → Safari → Extensions → Echo Inspector → Enable
   - macOS: Safari → Settings → Extensions → Echo Inspector → Enable

4. **Permissions** — The app will request microphone and speech recognition access on first launch (required for Voice Guide mode).

---

## How It Works

### Element Inspection
1. Open Safari and tap the Echo toolbar button
2. Tap **Start Inspecting** in the popup
3. Hover over elements to see a live highlight and tooltip
4. Click any element — data is sent to the native app via `browser.runtime.sendNativeMessage`
5. `SafariWebExtensionHandler` writes the element to the shared App Group container and fires a Darwin notification
6. `ExtensionBridgeService` receives the notification, runs `NLAnalysisService`, and updates the SwiftUI inspector tab
7. The analysis is spoken aloud automatically if Auto-speak is enabled

### Voice Commands
Say any of the following while an element is selected:
- **"analyze"** — full NL analysis of the selected element
- **"suggest"** — list accessibility and quality suggestions
- **"explain"** — what the element is and what it contains
- **"fix"** — first suggestion read aloud
- **"describe"** — full voice summary

---

## License

MIT © Omari Bell / Phoronomics Studio
