import WidgetKit
import SwiftUI

// MARK: - Echo on the Home Screen & Lock Screen
//
// Small: the orb — tap to talk.
// Medium: greeting + Talk · Screenshot · Live Guide, and the last thing Echo did.
// Lock Screen: circular orb, rectangular "Hey Echo", inline.

struct EchoEntry: TimelineEntry {
    let date: Date
    let name: String
    let lastAction: String?
}

struct EchoProvider: TimelineProvider {
    func placeholder(in context: Context) -> EchoEntry {
        EchoEntry(date: .now, name: "", lastAction: "Created reminder: Pay rent")
    }

    func getSnapshot(in context: Context, completion: @escaping (EchoEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EchoEntry>) -> Void) {
        // Greeting changes with the time of day; refresh every hour.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [current()], policy: .after(next)))
    }

    private func current() -> EchoEntry {
        EchoEntry(date: .now, name: EchoWidgetShared.userName, lastAction: EchoWidgetShared.lastAction)
    }
}

// MARK: Orb (lightweight version for widgets)

private struct WidgetOrb: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.55, green: 0.36, blue: 0.97).opacity(0.55), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.75))
                .frame(width: size * 1.5, height: size * 1.5)
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.45, blue: 1.0),
                                              Color(red: 0.20, green: 0.83, blue: 0.60)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: size * 0.32, height: size * 0.22)
                        .blur(radius: size * 0.06)
                        .offset(x: -size * 0.16, y: -size * 0.2)
                )
                .shadow(color: Color(red: 0.55, green: 0.36, blue: 0.97).opacity(0.6), radius: size * 0.2)
        }
        .accessibilityHidden(true)
    }
}

private func greeting(at date: Date) -> String {
    switch Calendar.current.component(.hour, from: date) {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<21: return "Good evening"
    default:      return "Good night"
    }
}

// MARK: Views

struct EchoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EchoEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "circle.hexagongrid.fill").font(.title2)
            }
            .widgetURL(URL(string: "echo://hey"))
            .accessibilityLabel("Hey Echo")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Hey Echo", systemImage: "circle.hexagongrid.fill").font(.headline)
                Text("Tap to talk").font(.caption)
            }
            .widgetURL(URL(string: "echo://hey"))
        case .accessoryInline:
            Label("Hey Echo", systemImage: "circle.hexagongrid.fill")
                .widgetURL(URL(string: "echo://hey"))
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(spacing: 10) {
            WidgetOrb(size: 64)
            Text("Hey Echo")
                .font(.system(.headline, design: .rounded))
            Text("Tap to talk")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "echo://hey"))
    }

    private var medium: some View {
        HStack(spacing: 14) {
            Link(destination: URL(string: "echo://hey")!) {
                WidgetOrb(size: 62)
                    .frame(width: 90)
            }
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(greeting(at: entry.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.name.isEmpty ? "What can I help with?" : "Hi \(entry.name)")
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    pill("Talk", "mic.fill", "echo://hey")
                    pill("Screen", "camera.viewfinder", "echo://last-screenshot")
                    pill("Guide", "dot.radiowaves.left.and.right", "echo://live")
                }
                if let last = entry.lastAction {
                    Text("Last: \(last)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func pill(_ title: String, _ icon: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.footnote.weight(.semibold))
                Text(title).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(red: 0.55, green: 0.36, blue: 0.97).opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityLabel(title)
    }
}

struct EchoWidgetExtension: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: EchoWidgetShared.kind, provider: EchoProvider()) { entry in
            EchoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.13),
                                            Color(red: 0.13, green: 0.10, blue: 0.24)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .environment(\.colorScheme, .dark)
        }
        .configurationDisplayName("Echo")
        .description("Tap to talk to Echo, explain your latest screenshot, or start a Live Guide.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    EchoWidgetExtension()
} timeline: {
    EchoEntry(date: .now, name: "Omari", lastAction: "Created reminder: Pay rent")
}
