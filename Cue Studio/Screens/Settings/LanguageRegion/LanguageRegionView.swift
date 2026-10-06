//
//  LanguageRegionView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Language & Region: the three languages Cue keeps apart. The app language is the interface's (the iPhone's to change);
/// the Voice Following language is what Cue listens for; the script language is what new scripts are written in. Changing one never
/// changes another or translates anything.
struct LanguageRegionView: View {
    let bindings: SettingsBindings

    var body: some View {
        List {
            Section {
                SettingsEntryRow(entry: .appLanguage, bindings: bindings)
            } footer: {
                Text("Opens iPhone Settings › Cue › Language.")
            }
            Section {
                SettingsEntryRow(entry: .voiceFollowingLanguage, bindings: bindings)
            } footer: {
                Text("The language Cue listens for while you speak.")
            }
            Section {
                SettingsEntryRow(entry: .scriptLanguage, bindings: bindings)
            } footer: {
                Text("New scripts start in it. Scripts are never translated.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Language & Region")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
