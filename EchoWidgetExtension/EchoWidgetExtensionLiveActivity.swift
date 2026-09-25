//
//  EchoWidgetExtensionLiveActivity.swift
//  EchoWidgetExtension
//
//  Created by Omari Bell on 9/24/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct EchoWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct EchoWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EchoWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension EchoWidgetExtensionAttributes {
    fileprivate static var preview: EchoWidgetExtensionAttributes {
        EchoWidgetExtensionAttributes(name: "World")
    }
}

extension EchoWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: EchoWidgetExtensionAttributes.ContentState {
        EchoWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: EchoWidgetExtensionAttributes.ContentState {
         EchoWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: EchoWidgetExtensionAttributes.preview) {
   EchoWidgetExtensionLiveActivity()
} contentStates: {
    EchoWidgetExtensionAttributes.ContentState.smiley
    EchoWidgetExtensionAttributes.ContentState.starEyes
}
