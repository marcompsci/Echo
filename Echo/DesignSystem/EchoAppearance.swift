import SwiftUI

// MARK: - Light / Dark mode
//
// The sun/moon toggle at the top right of Home flips Echo between light and
// dark. "Match iPhone" (Settings → Appearance) follows the system again.

enum EchoAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "echoAppearance"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Match iPhone"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// nil = follow the iPhone setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Top-right sun/moon button.
struct AppearanceToggle: View {
    @AppStorage(EchoAppearance.storageKey) private var appearanceRaw = EchoAppearance.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                appearanceRaw = (isDark ? EchoAppearance.light : .dark).rawValue
            }
        } label: {
            Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                .font(.echoTitle3)
                .foregroundStyle(isDark ? Color.echoWarning : Color.echoLavender)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 36)
                .background(Color.echoSurface, in: Circle())
        }
        .sensoryFeedback(.selection, trigger: appearanceRaw)
        .accessibilityLabel(isDark ? "Switch to light mode" : "Switch to dark mode")
    }
}
