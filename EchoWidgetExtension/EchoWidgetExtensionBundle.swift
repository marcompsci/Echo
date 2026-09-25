//
//  EchoWidgetExtensionBundle.swift
//  EchoWidgetExtension
//
//  Created by Omari Bell on 9/24/26.
//

import WidgetKit
import SwiftUI

@main
struct EchoWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        EchoWidgetExtension()
        EchoWidgetExtensionControl()
        EchoWidgetExtensionLiveActivity()
    }
}
