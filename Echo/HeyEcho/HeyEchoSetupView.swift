import SwiftUI

// MARK: - How to summon Hey Echo
//
// iOS doesn't let apps use the volume buttons, so these are the fastest
// Apple-supported ways to open Echo already listening.

struct HeyEchoSetupView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    EchoOrbView(size: 110)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                Text("Open Echo already listening — from anywhere on your iPhone.")
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextSecondary)
            }

            step("Action Button", icon: "button.horizontal.top.press",
                 "iPhone 15 Pro and newer: Settings → Action Button → swipe to Controls → choose **Hey Echo**. One press and Echo is listening.")
            step("Back Tap", icon: "hand.tap",
                 "Any iPhone: Settings → Accessibility → Touch → Back Tap → Double Tap → choose the **Hey Echo** shortcut. Double-tap the back of your phone to summon Echo.")
            step("Siri", icon: "waveform",
                 "Say **“Hey Siri, Hey Echo”** and Echo opens listening.")
            step("Lock Screen & Control Center", icon: "switch.2",
                 "Long-press your Lock Screen → Customize → tap a control slot → search **Echo** → Hey Echo. Or add it in Control Center the same way.")

            Section {
                Text("Why not the volume buttons? iOS reserves the hardware buttons for Apple. These options are the closest one-press way to reach Echo.")
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextTertiary)
            }
        }
        .navigationTitle("Set Up Hey Echo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ title: String, icon: String, _ detail: LocalizedStringKey) -> some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.echoHeadline)
                    Text(detail).font(.echoFootnote).foregroundStyle(.echoTextSecondary)
                }
            } icon: {
                Image(systemName: icon).foregroundStyle(.echoLavender)
            }
        }
    }
}
