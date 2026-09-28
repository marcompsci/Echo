import SwiftUI

struct QuickActionCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EchoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: EchoSpacing.Corner.md)
                        .fill(isPrimary ? LinearGradient.echoAccent : AnyShapeStyle(Color.echoSurfaceElevated))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isPrimary ? .white : AnyShapeStyle(LinearGradient.echoAccent))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextPrimary)
                    Text(subtitle)
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.echoFootnote.weight(.semibold))
                    .foregroundStyle(.echoTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(EchoSpacing.md)
            .background(Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
            .overlay(
                RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl)
                    .strokeBorder(
                        isPrimary ? AnyShapeStyle(LinearGradient.echoAccentSubtle) : AnyShapeStyle(Color.echoSeparator),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

#Preview {
    VStack(spacing: 12) {
        QuickActionCard(
            systemImage: "mic.fill",
            title: "Ask Echo",
            subtitle: "Hold to speak your question",
            isPrimary: true,
            action: {}
        )
        QuickActionCard(
            systemImage: "photo",
            title: "Import a Screenshot",
            subtitle: "Choose from your photo library",
            isPrimary: false,
            action: {}
        )
    }
    .padding()
    .background(Color.echoBackground)
}
