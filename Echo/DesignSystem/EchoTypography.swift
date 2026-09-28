import SwiftUI

// MARK: - Echo type scale (rounded design, scales with Dynamic Type)

extension Font {
    static let echoLargeTitle  = Font.system(.largeTitle,  design: .rounded, weight: .bold)
    static let echoTitle       = Font.system(.title,       design: .rounded, weight: .bold)
    static let echoTitle2      = Font.system(.title2,      design: .rounded, weight: .semibold)
    static let echoTitle3      = Font.system(.title3,      design: .rounded, weight: .semibold)
    static let echoHeadline    = Font.system(.headline,    design: .rounded, weight: .semibold)
    static let echoBody        = Font.system(.body,        design: .default, weight: .regular)
    static let echoCallout     = Font.system(.callout,     design: .default, weight: .regular)
    static let echoSubheadline = Font.system(.subheadline, design: .default, weight: .regular)
    static let echoFootnote    = Font.system(.footnote,    design: .default, weight: .regular)
    static let echoCaption     = Font.system(.caption,     design: .default, weight: .regular)
    static let echoCaption2    = Font.system(.caption2,    design: .default, weight: .regular)

    // Numeric / mono
    static let echoMono = Font.system(.body, design: .monospaced, weight: .medium)
}
