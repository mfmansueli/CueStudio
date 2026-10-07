//
//  PersonalizeView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize: the app icon, the topics, and how alive the app feels (the sky, the story moments, haptics). Everything
/// here stays on this iPhone, and the motion turns off with Reduce Motion.
struct PersonalizeView: View {
    let bindings: SettingsBindings

    var body: some View {
        List {
            Section {
                SettingsEntryRow(entry: .appIcon, bindings: bindings)
            } header: {
                CueSectionHeader("App icon")
            }
            Section {
                SettingsEntryRows(entries: [.topics, .autoTag], bindings: bindings)
            } header: {
                CueSectionHeader("Topics & colors")
            }
            Section {
                SettingsEntryRows(entries: [.starrySky, .celebrations, .haptics], bindings: bindings)
            } header: {
                CueSectionHeader("Motion")
            } footer: {
                Text("Never over your face or your edit. Off with Reduce Motion.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Personalize")
        .navigationBarTitleDisplayMode(.inline)
    }
}
