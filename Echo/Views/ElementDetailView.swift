import SwiftUI

struct ElementDetailView: View {
    let snapshot: ElementSnapshot
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var voice: VoiceGuidanceService
    @State private var selectedTab: DetailTab = .overview

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case html     = "HTML"
        case css      = "CSS"
        case attrs    = "Attributes"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tagHeader

                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case .overview: overviewContent
                    case .html:     htmlContent
                    case .css:      cssContent
                    case .attrs:    attrsContent
                    }
                }
            }
            .navigationTitle("Element Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        voice.speak(NLAnalysisService.shared.voiceSummary(for: snapshot))
                    } label: {
                        Image(systemName: "waveform")
                    }
                    .tint(.indigo)
                }
            }
        }
    }

    // MARK: - Tag Header

    private var tagHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.displayTitle)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(.indigo)
                if !snapshot.aiClassification.isEmpty {
                    Text(snapshot.aiClassification)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(snapshot.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Overview

    private var overviewContent: some View {
        VStack(spacing: 16) {
            if !snapshot.innerText.isEmpty {
                DetailCard(title: "Text Content") {
                    Text(snapshot.innerText.prefix(400))
                        .font(.callout)
                }
            }

            if !snapshot.aiSuggestions.isEmpty {
                DetailCard(title: "Suggestions", accentColor: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.aiSuggestions, id: \.self) { s in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange).padding(.top, 1)
                                Text(s).font(.caption)
                            }
                        }
                    }
                }
            }

            if !snapshot.aiInsights.isEmpty {
                DetailCard(title: "Insights", accentColor: .indigo) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.aiInsights, id: \.self) { i in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption).foregroundStyle(.indigo).padding(.top, 1)
                                Text(i).font(.caption)
                            }
                        }
                    }
                }
            }

            if !snapshot.xpath.isEmpty {
                DetailCard(title: "XPath") {
                    Text(snapshot.xpath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - HTML

    private var htmlContent: some View {
        DetailCard(title: "Outer HTML") {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(snapshot.outerHTML)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                copyToPasteboard(snapshot.outerHTML)
            } label: {
                Label("Copy HTML", systemImage: "doc.on.doc").font(.caption)
            }
            .tint(.indigo)
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - CSS

    private var cssContent: some View {
        DetailCard(title: "Computed Styles (\(snapshot.computedCSS.count))") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(snapshot.computedCSS.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(alignment: .top) {
                        Text(key)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.indigo)
                            .frame(width: 160, alignment: .leading)
                        Text(value)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Attributes

    private var attrsContent: some View {
        DetailCard(title: "HTML Attributes (\(snapshot.attributes.count))") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(snapshot.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(alignment: .top) {
                        Text(key)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.green)
                            .frame(width: 120, alignment: .leading)
                        Text(value.isEmpty ? "(empty)" : value)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(value.isEmpty ? .tertiary : .secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func copyToPasteboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

// MARK: - Detail Card

struct DetailCard<Content: View>: View {
    let title: String
    var accentColor: Color = .secondary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .textCase(.uppercase)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
