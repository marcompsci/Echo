import SwiftUI

struct PrivacyPromiseCard: View {
    private let promises: [(icon: String, text: String)] = [
        ("eye.slash", "No background screen watching"),
        ("mic.slash", "No silent microphone recording"),
        ("trash", "Delete sessions whenever you want")
    ]

    var body: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.md) {
                Label {
                    Text("Echo's privacy promise")
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextPrimary)
                } icon: {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(LinearGradient.echoAccent)
                }

                Divider()
                    .background(Color.echoSeparator)

                VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                    ForEach(promises, id: \.text) { item in
                        HStack(spacing: EchoSpacing.sm) {
                            Image(systemName: item.icon)
                                .font(.echoCallout)
                                .foregroundStyle(.echoMint)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(item.text)
                                .font(.echoSubheadline)
                                .foregroundStyle(.echoTextSecondary)
                        }
                    }
                }
            }
            .padding(EchoSpacing.lg)
        }
    }
}

#Preview {
    ZStack {
        Color.echoBackground.ignoresSafeArea()
        PrivacyPromiseCard()
            .padding()
    }
}
