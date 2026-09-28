import SwiftUI

struct AgentResultCard: View {
    let result: AgentResult
    @State private var expanded = true

    var body: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                // Header
                HStack {
                    Image(systemName: result.isFullySuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(result.isFullySuccessful ? .echoMint : .echoWarning)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.plan.title)
                            .font(.echoHeadline)
                            .foregroundStyle(.echoTextPrimary)
                        Text(statusLine)
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextSecondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                            .rotationEffect(.degrees(expanded ? 0 : -90))
                    }
                    .accessibilityLabel(expanded ? "Collapse" : "Expand")
                }

                if expanded {
                    Divider().background(Color.echoSeparator)

                    // Completed actions
                    if !result.completedActions.isEmpty {
                        VStack(alignment: .leading, spacing: EchoSpacing.xxs) {
                            ForEach(result.completedActions) { action in
                                HStack(spacing: EchoSpacing.xs) {
                                    Image(systemName: "checkmark")
                                        .font(.echoCaption2.weight(.bold))
                                        .foregroundStyle(.echoMint)
                                        .frame(width: 14)
                                        .accessibilityHidden(true)
                                    Text(action.summary)
                                        .font(.echoCaption)
                                        .foregroundStyle(.echoTextSecondary)
                                }
                            }
                        }
                    }

                    // Failed actions
                    if !result.failedActions.isEmpty {
                        VStack(alignment: .leading, spacing: EchoSpacing.xxs) {
                            ForEach(result.failedActions, id: \.0.id) { (action, error) in
                                HStack(alignment: .top, spacing: EchoSpacing.xs) {
                                    Image(systemName: "xmark")
                                        .font(.echoCaption2.weight(.bold))
                                        .foregroundStyle(.echoDestructive)
                                        .frame(width: 14)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.summary)
                                            .font(.echoCaption)
                                            .foregroundStyle(.echoTextPrimary)
                                        Text(error)
                                            .font(.echoCaption2)
                                            .foregroundStyle(.echoDestructive)
                                    }
                                }
                            }
                        }
                    }

                    Text(result.completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.echoCaption2)
                        .foregroundStyle(.echoTextTertiary)
                }
            }
            .padding(EchoSpacing.md)
        }
    }

    private var statusLine: String {
        if result.isFullySuccessful {
            return "\(result.successCount) action\(result.successCount == 1 ? "" : "s") completed"
        } else {
            return "\(result.successCount) done · \(result.failureCount) failed"
        }
    }
}
