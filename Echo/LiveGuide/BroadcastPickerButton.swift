import SwiftUI
import ReplayKit

// MARK: - System "Start Screen Sharing" button, pre-set to Echo's extension
//
// Apple only allows starting a screen broadcast from its own picker button.
// We place the real (invisible) picker over a styled Echo button so a tap on
// our button is a tap on Apple's.

struct BroadcastPickerButton: View {
    let title: String

    var body: some View {
        ZStack {
            Label(title, systemImage: "record.circle")
                .font(.echoHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(LinearGradient.echoAccent)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))

            SystemBroadcastPicker()
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .opacity(0.02)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

private struct SystemBroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 300, height: 54))
        picker.preferredExtension = LiveGuideStore.extensionBundleID
        picker.showsMicrophoneButton = false
        // Stretch Apple's inner button over the whole area so any tap triggers it.
        for case let button as UIButton in picker.subviews {
            button.frame = picker.bounds
            button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        for case let button as UIButton in uiView.subviews {
            button.frame = uiView.bounds
        }
    }
}
