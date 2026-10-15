//
//  EchoWidgetExtensionLiveActivity.swift
//  EchoWidgetExtension
//
//  Echo's orb on the Lock Screen and in the Dynamic Island.
//  Tapping anywhere opens Echo already listening (echo://hey).
//

import ActivityKit
import WidgetKit
import SwiftUI

private let lavender = Color(red: 0.545, green: 0.361, blue: 0.965)
private let mint = Color(red: 0.204, green: 0.827, blue: 0.600)

/// A static glowing orb (Live Activities can't run continuous animations,
/// so the look changes with Echo's status instead).
private struct MiniOrb: View {
    let status: EchoActivityAttributes.ContentState.Status
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [glow.opacity(0.6), .clear],
                                     center: .center, startRadius: size * 0.2, endRadius: size * 0.75))
                .frame(width: size * 1.5, height: size * 1.5)
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.95), lavender, mint.opacity(0.9)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
                .frame(width: size, height: size)
                .scaleEffect(status == .speaking || status == .listening ? 1.12 : 1)
        }
        .accessibilityLabel("Echo")
    }

    private var glow: Color {
        switch status {
        case .listening: return mint
        case .speaking, .guiding: return lavender
        case .done: return .green
        default: return lavender.opacity(0.6)
        }
    }
}

private func statusTitle(_ status: EchoActivityAttributes.ContentState.Status) -> String {
    switch status {
    case .ready: return "Echo"
    case .listening: return "Listening…"
    case .thinking: return "Thinking…"
    case .speaking: return "Echo"
    case .guiding: return "Live Guide"
    case .done: return "Done"
    }
}

struct EchoWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EchoActivityAttributes.self) { context in
            // Lock Screen / banner
            HStack(spacing: 14) {
                MiniOrb(status: context.state.status, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.step > 0 ? "Step \(context.state.step)" : statusTitle(context.state.status))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(context.state.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "mic.fill")
                    .foregroundStyle(mint)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.75))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "echo://hey"))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MiniOrb(status: context.state.status, size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "echo://hey")!) {
                        Image(systemName: "mic.circle.fill")
                            .font(.title)
                            .foregroundStyle(mint)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.step > 0 ? "Step \(context.state.step)" : statusTitle(context.state.status))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } compactLeading: {
                MiniOrb(status: context.state.status, size: 18)
            } compactTrailing: {
                Text(context.state.step > 0 ? "\(context.state.step)" : (context.state.status == .listening ? "…" : ""))
                    .foregroundStyle(mint)
            } minimal: {
                MiniOrb(status: context.state.status, size: 16)
            }
            .widgetURL(URL(string: "echo://hey"))
            .keylineTint(lavender)
        }
    }
}

#Preview("Lock Screen", as: .content, using: EchoActivityAttributes(userName: "Omari")) {
    EchoWidgetExtensionLiveActivity()
} contentStates: {
    EchoActivityAttributes.ContentState(status: .ready, message: "Hi Omari — tap to talk")
    EchoActivityAttributes.ContentState(status: .guiding, message: "Tap Display & Brightness", step: 2)
}
