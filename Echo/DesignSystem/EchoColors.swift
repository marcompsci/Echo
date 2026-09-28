import SwiftUI

// MARK: - Echo adaptive color palette

extension Color {
    // Backgrounds — deep midnight navy (dark) / soft off-white (light)
    static let echoBackground = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.051, green: 0.071, blue: 0.129, alpha: 1)
            : UIColor(red: 0.961, green: 0.961, blue: 0.980, alpha: 1)
    })

    static let echoSurface = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.098, green: 0.122, blue: 0.212, alpha: 1)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })

    static let echoSurfaceElevated = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.137, green: 0.165, blue: 0.271, alpha: 1)
            : UIColor(red: 0.953, green: 0.953, blue: 0.971, alpha: 1)
    })

    // Brand accent — electric lavender → mint (same in both modes)
    static let echoLavender    = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
    static let echoMint        = Color(red: 0.204, green: 0.831, blue: 0.600) // #34D399
    static let echoWarning     = Color(red: 0.957, green: 0.741, blue: 0.204) // #F4BD34
    static let echoDestructive = Color(red: 0.961, green: 0.361, blue: 0.361) // #F55C5C

    // Adaptive text
    static let echoTextPrimary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.961, green: 0.961, blue: 0.980, alpha: 1)
            : UIColor(red: 0.051, green: 0.071, blue: 0.129, alpha: 1)
    })

    static let echoTextSecondary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.698, green: 0.706, blue: 0.796, alpha: 1)
            : UIColor(red: 0.373, green: 0.400, blue: 0.525, alpha: 1)
    })

    static let echoTextTertiary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.447, green: 0.459, blue: 0.565, alpha: 1)
            : UIColor(red: 0.569, green: 0.588, blue: 0.682, alpha: 1)
    })

    // Separator
    static let echoSeparator = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(white: 0.0, alpha: 0.08)
    })
}

// MARK: - Gradients

extension LinearGradient {
    static var echoAccent: LinearGradient {
        LinearGradient(
            colors: [.echoLavender, .echoMint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var echoAccentSubtle: LinearGradient {
        LinearGradient(
            colors: [.echoLavender.opacity(0.18), .echoMint.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var echoBackground: LinearGradient {
        LinearGradient(
            colors: [Color.echoBackground, Color.echoSurface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension RadialGradient {
    static func echoOrbGlow(radius: CGFloat = 100) -> RadialGradient {
        RadialGradient(
            colors: [
                Color.echoLavender.opacity(0.55),
                Color.echoMint.opacity(0.30),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
    }
}

// MARK: - Annotation colors

extension Color {
    static func echoAnnotation(_ style: AnnotationColorStyle) -> Color {
        switch style {
        case .accent:  return .echoLavender
        case .warning: return .echoWarning
        case .success: return .echoMint
        }
    }
}

// Keep AnnotationColorStyle accessible here for the color helper above.
// The canonical definition lives in Annotation.swift.
typealias AnnotationColorStyle = Annotation.ColorStyle
