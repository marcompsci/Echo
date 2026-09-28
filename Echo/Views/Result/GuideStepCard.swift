import SwiftUI

struct GuideStepCard: View {
    let step: GuideStep
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: EchoSpacing.md) {
                // Step number badge
                ZStack {
                    Circle()
                        .fill(isSelected ? LinearGradient.echoAccent : AnyShapeStyle(Color.echoSurfaceElevated))
                        .frame(width: 36, height: 36)
                    Text("\(step.number)")
                        .font(.echoHeadline)
                        .foregroundStyle(isSelected ? .white : .echoTextSecondary)
                }
                .animation(.spring(duration: 0.25), value: isSelected)

                VStack(alignment: .leading, spacing: EchoSpacing.xxs) {
                    Text(step.title)
                        .font(.echoHeadline)
                        .foregroundStyle(isSelected ? .echoTextPrimary : .echoTextSecondary)
                        .multilineTextAlignment(.leading)

                    if isSelected {
                        Text(step.detail)
                            .font(.echoSubheadline)
                            .foregroundStyle(.echoTextSecondary)
                            .multilineTextAlignment(.leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(EchoSpacing.md)
            .background(isSelected ? Color.echoSurfaceElevated : Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
            .overlay(
                RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(LinearGradient.echoAccentSubtle)
                            : AnyShapeStyle(Color.echoSeparator),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: isSelected)
        .accessibilityLabel("Step \(step.number): \(step.title)")
        .accessibilityHint(isSelected ? step.detail : "Tap to expand")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: 8) {
        GuideStepCard(
            step: GuideStep(number: 1, title: "Tap the highlighted option", detail: "It is the most likely place to continue from this screen."),
            isSelected: true,
            onTap: {}
        )
        GuideStepCard(
            step: GuideStep(number: 2, title: "Review the choices", detail: "Look for wording that matches your goal."),
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color.echoBackground)
}
