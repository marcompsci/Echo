import SwiftUI

// MARK: - Shows Echo's proposed plan and lets the user confirm or cancel

struct AgentPlanView: View {
    let plan: AgentPlan
    let onConfirm: () -> Void
    let onCancel: () -> Void

    // AgentAction.id is String — track which row is expanded by its string id
    @State private var expandedActionID: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.echoBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: EchoSpacing.lg) {
                        headerSection
                        actionsSection
                        if plan.hasDestructiveActions { warningSection }
                        buttonSection
                    }
                    .padding(.horizontal, EchoSpacing.md)
                    .padding(.top, EchoSpacing.md)
                    .padding(.bottom, EchoSpacing.xxxl)
                }
            }
            .navigationTitle("Review Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.echoBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.echoTextSecondary)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                HStack(spacing: EchoSpacing.sm) {
                    EchoOrb(size: 36).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(.echoHeadline)
                            .foregroundStyle(.echoTextPrimary)
                        Text("\(plan.actions.count) action\(plan.actions.count == 1 ? "" : "s")")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                    }
                }
                Text(plan.explanation)
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(EchoSpacing.md)
        }
    }

    // MARK: - Actions list

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            Text("What Echo will do")
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)

            VStack(spacing: EchoSpacing.xs) {
                ForEach(plan.actions) { action in
                    AgentActionRow(
                        action: action,
                        isExpanded: expandedActionID == action.id,
                        onTap: {
                            withAnimation(.spring(duration: 0.3)) {
                                expandedActionID = (expandedActionID == action.id) ? nil : action.id
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Warning for destructive actions

    private var warningSection: some View {
        HStack(alignment: .top, spacing: EchoSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.echoWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(plan.destructiveCount) irreversible action\(plan.destructiveCount == 1 ? "" : "s")")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoWarning)
                Text(plan.safetyNotice ?? "Once confirmed, these changes cannot be undone.")
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(EchoSpacing.md)
        .background(Color.echoWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
        .overlay(
            RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg)
                .strokeBorder(Color.echoWarning.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: EchoSpacing.sm) {
            EchoButton(
                plan.hasDestructiveActions ? "Confirm & Execute" : "Run These Actions",
                systemImage: "checkmark.circle.fill",
                role: plan.hasDestructiveActions ? .destructive : nil,
                action: onConfirm
            )
            EchoSecondaryButton("Cancel — don't do this", action: onCancel)
        }
    }
}

// MARK: - Single action row (expandable)

private struct AgentActionRow: View {
    let action: AgentAction
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: EchoSpacing.xs) {
                HStack(spacing: EchoSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: EchoSpacing.Corner.sm)
                            .fill(action.isDestructive
                                  ? Color.echoDestructive.opacity(0.15)
                                  : LinearGradient.echoAccentSubtle)
                            .frame(width: 36, height: 36)
                        Image(systemName: action.icon)
                            .font(.echoSubheadline)
                            .foregroundStyle(action.isDestructive ? .echoDestructive : .echoLavender)
                    }
                    .accessibilityHidden(true)

                    Text(action.summary)
                        .font(.echoSubheadline)
                        .foregroundStyle(.echoTextPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if action.isDestructive {
                        Text("Irreversible")
                            .font(.echoCaption2)
                            .foregroundStyle(.echoDestructive)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.echoDestructive.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.down")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                if isExpanded, let warning = action.irreversibilityWarning {
                    Text(warning)
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextSecondary)
                        .padding(.leading, 44)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(EchoSpacing.md)
            .background(Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.summary)
        .accessibilityHint(action.isDestructive ? "Irreversible. Tap to expand." : "Tap to expand.")
    }
}

#Preview {
    AgentPlanView(
        plan: AgentPlan(
            title: "Delete matching contacts",
            explanation: "Echo found 3 contacts that match your description.",
            actions: [
                .deleteContact(id: "1", displayName: "John Doe (2019)"),
                .deleteContact(id: "2", displayName: "Jane Smith (2019)"),
                .createReminder(title: "Follow up", dueDate: .now)
            ],
            safetyNotice: "Deletion is permanent. Export a backup first if needed."
        ),
        onConfirm: {},
        onCancel: {}
    )
}
