//
//  DockMotionLogging.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests (`-uiTestDockMotionLog`): the dock counts each of its lights in an element only tests read (`dock.motionLog`), so a test
    /// checks which chip lit, and when, without filming the screen.
    @Entry var logsDockMotion = false
}

/// UI tests (`logsDockMotion`): what the dock's lights have done, for a test to read (`dock.motionLog`). Never seen.
struct DockMotionLog: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(.clear)
            .frame(width: 1, height: 1)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityIdentifier("dock.motionLog")
    }
}
