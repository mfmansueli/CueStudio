//
//  SettingsRecordingView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Recording: the camera every recording starts with, its quality and format, the microphone, and what happens
/// while recording.
struct SettingsRecordingView: View {
    let bindings: SettingsBindings

    var body: some View {
        List {
            Section {
                SettingsEntryRow(entry: .startsWith, bindings: bindings)
            } header: {
                CueSectionHeader("Camera")
            } footer: {
                Text("Flip anytime while recording.")
            }
            Section {
                SettingsEntryRow(entry: .resolution, bindings: bindings)
                SettingsEntryRow(entry: .frameRate, bindings: bindings)
            } header: {
                CueSectionHeader("Quality")
            } footer: {
                Text("A platform can suggest another setup. You choose.")
            }
            Section {
                SettingsEntryRow(entry: .defaultFormat, bindings: bindings)
            } header: {
                CueSectionHeader("Default format")
            } footer: {
                Text("Framing, safe zones and export follow it.")
            }
            Section {
                SettingsEntryRow(entry: .microphone, bindings: bindings)
            } header: {
                CueSectionHeader("Microphone")
            } footer: {
                Text("Uses a connected mic when there is one.")
            }
            Section {
                SettingsEntryRow(entry: .countdown, bindings: bindings)
                SettingsEntryRow(entry: .grid, bindings: bindings)
            } header: {
                CueSectionHeader("While recording")
            }
        }
        .cueGroupedList()
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
    }
}
