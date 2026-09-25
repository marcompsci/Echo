import Foundation
import SwiftData

@Model
final class ElementSnapshot {
    var id: UUID
    var timestamp: Date
    var tagName: String
    var elementId: String
    var className: String
    var innerText: String
    var outerHTML: String
    var xpath: String
    var pageURL: String
    var pageTitle: String
    var aiClassification: String
    var aiInsights: [String]
    var aiSuggestions: [String]

    // Stored as JSON strings for SwiftData compatibility
    private var computedCSSRaw: String
    private var attributesRaw: String

    var computedCSS: [String: String] {
        get {
            guard let data = computedCSSRaw.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return dict
        }
        set {
            computedCSSRaw = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
        }
    }

    var attributes: [String: String] {
        get {
            guard let data = attributesRaw.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return dict
        }
        set {
            attributesRaw = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
        }
    }

    init(tagName: String, elementId: String = "", className: String = "",
         innerText: String = "", outerHTML: String = "", xpath: String = "",
         pageURL: String = "", pageTitle: String = "") {
        self.id = UUID()
        self.timestamp = Date()
        self.tagName = tagName
        self.elementId = elementId
        self.className = className
        self.innerText = innerText
        self.outerHTML = outerHTML
        self.xpath = xpath
        self.pageURL = pageURL
        self.pageTitle = pageTitle
        self.aiClassification = ""
        self.aiInsights = []
        self.aiSuggestions = []
        self.computedCSSRaw = "{}"
        self.attributesRaw = "{}"
    }

    var displayTitle: String {
        var parts: [String] = ["<\(tagName.lowercased())>"]
        if !elementId.isEmpty { parts.append("#\(elementId)") }
        if !className.isEmpty {
            let firstClass = className.split(separator: " ").prefix(2).joined(separator: " ")
            parts.append(".\(firstClass)")
        }
        return parts.joined(separator: " ")
    }
}
