import SwiftUI

struct SensitiveContentWarning: View {
    let message: String
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            HStack(alignment: .top, spacing: EchoSpacing.sm) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.echoWarning)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.echoCaption2)
                        .foregroundStyle(.echoTextTertiary)
                }
                .accessibilityLabel("Dismiss warning")
            }
            .padding(EchoSpacing.md)
            .background(Color.echoWarning.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
            .overlay(
                RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg)
                    .strokeBorder(Color.echoWarning.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack {
        SensitiveContentWarning(
            message: "Before sharing: remove passwords, private messages, payment details, or anything you do not want analyzed."
        )
        .padding()
    }
    .background(Color.echoBackground)
}
