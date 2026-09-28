import SwiftUI

// MARK: - Primary gradient button

struct EchoButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: EchoSpacing.xs) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.echoHeadline)
                }
                Text(title)
                    .font(.echoHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoSpacing.md)
            .background(role == .destructive ? AnyShapeStyle(Color.echoDestructive) : AnyShapeStyle(LinearGradient.echoAccent))
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Secondary (outlined) button

struct EchoSecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: EchoSpacing.xs) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.echoSubheadline)
                }
                Text(title)
                    .font(.echoSubheadline)
            }
            .foregroundStyle(.echoTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoSpacing.sm)
            .background(Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
            .overlay(
                RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl)
                    .strokeBorder(Color.echoSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: 16) {
        EchoButton("Ask Echo", systemImage: "mic.fill") {}
        EchoSecondaryButton("Import a Screenshot", systemImage: "photo") {}
        EchoButton("Delete guide", role: .destructive) {}
    }
    .padding()
    .background(Color.echoBackground)
}
