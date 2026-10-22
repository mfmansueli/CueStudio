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

    @Environment(LanguageService.self) private var languages
    @Environment(LanguageCapabilityService.self) private var capabilities
    /// Whether Apple Intelligence drafts in the picked Script Language (nil on Auto-detect, or until asked).
    @State private var scriptAIWriting: FeatureSupport?

    /// The script language's footer, and the reason when Apple Intelligence can't draft in the language picked (never on Auto-detect,
    /// where each script's language is its own).
    private var scriptFooter: String {
        let footer = String(localized: "New scripts start in it. Scripts are never translated.")
        guard let language = languages.scriptLanguage, case .unavailable(.languageNotSupported)? = scriptAIWriting else { return footer }
        return footer + " " + String(localized: "Apple Intelligence can’t draft in \(language.localizedName) yet.")
    }

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
                Text(scriptFooter)
                    .accessibilityIdentifier("languageRegion.scriptFooter")
            }
        }
        .task(id: languages.scriptLanguage) {
            if let language = languages.scriptLanguage {
                scriptAIWriting = await capabilities.support(.aiWriting, for: language)
            } else {
                scriptAIWriting = nil
            }
        }
        .cueGroupedList()
        .navigationTitle("Language & Region")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
