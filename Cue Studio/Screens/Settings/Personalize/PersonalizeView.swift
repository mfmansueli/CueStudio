//
//  PersonalizeView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize: the app icon, the topics, how alive the app feels (the sky, the story moments, haptics) and, until the first
/// video is shared, the first video guide. Everything
/// here stays on this iPhone, and the motion turns off with Reduce Motion.
struct PersonalizeView: View {
    let bindings: SettingsBindings

    @Environment(FirstVoyageService.self) private var voyage

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
            if voyage.canBeTurnedOn {
                // The first voyage, while it can still help: "Hide guide" sends creators here to bring it back.
                Section {
                    SettingsEntryRow(entry: .firstVoyage, bindings: bindings)
                } header: {
                    CueSectionHeader("Getting started")
                }
            }
        }
        .cueGroupedList()
        .navigationTitle("Personalize")
        .navigationBarTitleDisplayMode(.inline)
    }
}
