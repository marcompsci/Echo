import Foundation
import NaturalLanguage

final class NLAnalysisService {
    static let shared = NLAnalysisService()

    private let languageRecognizer = NLLanguageRecognizer()

    // Main entry point — fills in a snapshot's AI fields in place
    func analyze(snapshot: ElementSnapshot) {
        snapshot.aiClassification = classifyElement(snapshot)
        snapshot.aiInsights = buildInsights(snapshot)
        snapshot.aiSuggestions = buildSuggestions(snapshot)
    }

    // MARK: - Classification

    private func classifyElement(_ s: ElementSnapshot) -> String {
        let tag = s.tagName.lowercased()
        switch tag {
        case "nav": return "Navigation"
        case "header": return "Page Header"
        case "footer": return "Page Footer"
        case "aside": return "Sidebar"
        case "main": return "Main Content"
        case "article": return "Article"
        case "section": return "Section"
        case "button": return "Interactive Button"
        case "a": return "Hyperlink"
        case "form": return "Form"
        case "input", "select", "textarea": return "Form Control"
        case "img": return "Image"
        case "video": return "Video"
        case "audio": return "Audio"
        case "canvas": return "Canvas"
        case "svg": return "SVG Graphic"
        case "table", "thead", "tbody": return "Data Table"
        case "ul", "ol": return "List"
        case "script": return "Script Resource"
        case "style", "link": return "Style Resource"
        default: return classifyByContent(s)
        }
    }

    private func classifyByContent(_ s: ElementSnapshot) -> String {
        let cls = s.className.lowercased()
        let hints: [(String, String)] = [
            ("nav", "Navigation"),   ("menu", "Navigation"),
            ("btn", "Button-like"),  ("button", "Button-like"),
            ("card", "Card Component"), ("modal", "Modal/Dialog"),
            ("dialog", "Modal/Dialog"), ("hero", "Hero Section"),
            ("banner", "Banner"),   ("form", "Form Container"),
            ("grid", "Grid Layout"), ("row", "Row Layout"),
            ("col", "Column Layout"), ("icon", "Icon"),
            ("logo", "Logo/Brand"), ("spinner", "Loading Indicator"),
            ("toast", "Notification"), ("alert", "Alert"),
            ("badge", "Badge"),      ("chip", "Chip"),
            ("avatar", "Avatar"),    ("thumbnail", "Thumbnail"),
        ]
        for (keyword, label) in hints where cls.contains(keyword) { return label }
        if s.innerText.isEmpty { return "Empty Container" }
        if s.innerText.count < 60 { return "Short Text" }
        return "Content Block"
    }

    // MARK: - Insights

    private func buildInsights(_ s: ElementSnapshot) -> [String] {
        var insights: [String] = []

        // Language detection on visible text
        if !s.innerText.isEmpty {
            languageRecognizer.reset()
            languageRecognizer.processString(s.innerText)
            if let lang = languageRecognizer.dominantLanguage, lang != .undetermined {
                insights.append("Detected language: \(lang.rawValue.uppercased())")
            }

            // Code pattern detection
            let codeSignals = ["{", "}", "function ", "const ", "var ", "=>", "class ", "import ", "return "]
            let codeHits = codeSignals.filter { s.innerText.contains($0) }.count
            if codeHits >= 3 {
                insights.append("Content appears to contain source code")
            }
        }

        // Naming convention analysis
        let classes = s.className.split(separator: " ").map(String.init)
        if classes.count > 1 {
            let hasBEM = classes.contains { $0.contains("__") || $0.contains("--") }
            let hasCamel = classes.contains { c in c.first?.isLowercase == true && c.contains(where: { $0.isUppercase }) }
            let hasKebab = classes.contains { $0.contains("-") && !$0.contains("__") && !$0.contains("--") }
            var conventions: [String] = []
            if hasBEM { conventions.append("BEM") }
            if hasCamel { conventions.append("camelCase") }
            if hasKebab { conventions.append("kebab-case") }
            if conventions.count > 1 {
                insights.append("Mixed CSS naming conventions: \(conventions.joined(separator: " + "))")
            }
        }

        // Depth estimation from XPath
        let depth = s.xpath.split(separator: "/").count
        if depth > 12 {
            insights.append("Deep DOM nesting (\(depth) levels) — may affect performance")
        }

        // Link detection inside text
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(s.innerText.startIndex..., in: s.innerText)
            let count = detector.numberOfMatches(in: s.innerText, range: range)
            if count > 0 { insights.append("Contains \(count) URL(s) in text content") }
        }

        // Class density insight
        let classCount = classes.count
        if classCount >= 6 {
            insights.append("\(classCount) CSS classes applied — consider utility-class audit")
        }

        return insights
    }

    // MARK: - Suggestions

    private func buildSuggestions(_ s: ElementSnapshot) -> [String] {
        var suggestions: [String] = []
        let tag = s.tagName.lowercased()
        let attrs = s.attributes

        // Accessibility checks
        if tag == "img" && (attrs["alt"] == nil || attrs["alt"]?.trimmingCharacters(in: .whitespaces).isEmpty == true) {
            suggestions.append("Add descriptive alt text to <img> for screen reader support")
        }

        if tag == "button" && s.innerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attrs["aria-label"] == nil {
            suggestions.append("Button has no visible text or aria-label — add an accessible name")
        }

        if tag == "a" {
            if attrs["href"] == nil {
                suggestions.append("<a> is missing href attribute — use <button> for non-navigation actions")
            }
            let genericTexts = ["click here", "read more", "learn more", "here", "more"]
            if genericTexts.contains(s.innerText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
                suggestions.append("Non-descriptive link text '\(s.innerText.trimmingCharacters(in: .whitespacesAndNewlines))' — use meaningful text")
            }
        }

        if ["input", "select", "textarea"].contains(tag) &&
           attrs["aria-label"] == nil && attrs["aria-labelledby"] == nil && s.elementId.isEmpty {
            suggestions.append("Form control may lack a programmatic label — add <label for=…> or aria-label")
        }

        // Deprecated element check
        let deprecated = ["font", "center", "marquee", "blink", "frame", "frameset", "big", "strike", "tt"]
        if deprecated.contains(tag) {
            suggestions.append("Deprecated tag <\(tag)> — replace with modern HTML/CSS equivalent")
        }

        // Inline styles
        if s.outerHTML.contains("style=\"") {
            suggestions.append("Inline styles detected — consider extracting to a CSS class")
        }

        // XSS patterns
        if s.outerHTML.contains("dangerouslySetInnerHTML") || s.outerHTML.contains("v-html=") || s.outerHTML.contains("innerHTML") {
            suggestions.append("Raw HTML injection pattern detected — review for XSS vulnerability")
        }

        // Anonymous div/span with no semantic role
        if (tag == "div" || tag == "span") && s.className.isEmpty && s.elementId.isEmpty && attrs["role"] == nil {
            suggestions.append("Anonymous <\(tag)> with no class, id, or role — consider a semantic element")
        }

        // tabindex -1 warning
        if attrs["tabindex"] == "-1" {
            suggestions.append("tabindex=\"-1\" removes element from keyboard tab order — verify intent")
        }

        return suggestions
    }

    // MARK: - Voice Summary

    func voiceSummary(for snapshot: ElementSnapshot) -> String {
        var parts: [String] = []
        parts.append("Selected \(snapshot.tagName.lowercased()) element.")
        if !snapshot.aiClassification.isEmpty { parts.append("Classified as \(snapshot.aiClassification).") }
        if !snapshot.elementId.isEmpty { parts.append("ID: \(snapshot.elementId).") }
        if !snapshot.innerText.isEmpty {
            let preview = String(snapshot.innerText.prefix(100))
            parts.append("Text content: \(preview).")
        }
        if !snapshot.aiSuggestions.isEmpty {
            parts.append("\(snapshot.aiSuggestions.count) accessibility or quality suggestion\(snapshot.aiSuggestions.count == 1 ? "" : "s") found.")
            parts.append(snapshot.aiSuggestions[0])
        }
        return parts.joined(separator: " ")
    }
}
