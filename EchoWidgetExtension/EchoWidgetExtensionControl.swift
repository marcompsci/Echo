//
//  EchoWidgetExtensionControl.swift
//  EchoWidgetExtension
//
//  Control Center / Lock Screen / Action Button controls — Echo's "hotkey".
//  Take a screenshot, then tap "Ask Echo" to get help with it.
//

import AppIntents
import SwiftUI
import WidgetKit

struct EchoWidgetExtensionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "phoronomicstudios.com.Echo.AskEcho") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "echo://last-screenshot")!)) {
                Label("Ask Echo", systemImage: "camera.viewfinder")
            }
        }
        .displayName("Ask Echo")
        .description("Open your latest screenshot in Echo and ask what to do next.")
    }
}

struct EchoAgentControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "phoronomicstudios.com.Echo.EchoAgent") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "echo://agent")!)) {
                Label("Echo Agent", systemImage: "wand.and.stars")
            }
        }
        .displayName("Echo Agent")
        .description("Ask Echo to create a reminder, note, contact, or album.")
    }
}

struct EchoLiveGuideControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "phoronomicstudios.com.Echo.LiveGuide") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "echo://live")!)) {
                Label("Echo Live Guide", systemImage: "eye")
            }
        }
        .displayName("Echo Live Guide")
        .description("Let Echo watch your screen and talk you through a task.")
    }
}

/// "Hey Echo" — put it on the Action Button, Lock Screen, or Control Center.
struct HeyEchoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "phoronomicstudios.com.Echo.HeyEcho") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "echo://hey")!)) {
                Label("Hey Echo", systemImage: "waveform.circle.fill")
            }
        }
        .displayName("Hey Echo")
        .description("Open Echo already listening.")
    }
}
