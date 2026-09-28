import SwiftUI

struct ActionSuggestionCard: View {
    let action: ActionSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: EchoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: EchoSpacing.Corner.md)
                        .fill(LinearGradient.echoAccentSubtle)
                        .frame(width: 44, height: 44)
                    Image(systemName: action.systemImage)
                        .font(.echoHeadline)
                        .foregroundStyle(LinearGradient.echoAccent)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.echoSubheadline.weight(.semibold))
                        .foregroundStyle(.echoTextPrimary)
                    Text(action.subtitle)
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextSecondary)
                }

                Spacer()

                Image(systemName: action.requiresConfirmation ? "arrow.right.circle" : "arrow.up.right.circle")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(EchoSpacing.md)
            .background(Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.requiresConfirmation ? "Requires confirmation" : action.subtitle)
    }
}

#Preview {
    VStack(spacing: 8) {
        ActionSuggestionCard(
            action: ActionSuggestion(title: "Save these steps to Notes", subtitle: "Keep a copy in Apple Notes.", systemImage: "note.text", actionType: .createNote),
            onTap: {}
        )
        ActionSuggestionCard(
            action: ActionSuggestion(title: "Share this guide", subtitle: "Send to someone else.", systemImage: "square.and.arrow.up", actionType: .shareGuide, requiresConfirmation: false),
            onTap: {}
        )
    }
    .padding()
    .background(Color.echoBackground)
}
