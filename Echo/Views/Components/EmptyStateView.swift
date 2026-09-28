import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: EchoSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.echoAccent)
                .accessibilityHidden(true)

            Text(title)
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.echoSubheadline)
                .foregroundStyle(.echoTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(EchoSpacing.xl)
    }
}

#Preview {
    ZStack {
        Color.echoBackground.ignoresSafeArea()
        EmptyStateView(
            systemImage: "square.stack.3d.up.slash",
            title: "Your guides will appear here",
            subtitle: "Import a screenshot and ask Echo a question to get started."
        )
    }
}
