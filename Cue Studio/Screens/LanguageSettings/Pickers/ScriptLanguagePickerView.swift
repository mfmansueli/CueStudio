//
//  ScriptLanguagePickerView.swift
//  Cue Studio
//

import SwiftUI

/// Language & Region › Script Language: what new scripts are marked as. Existing scripts keep
/// their own language and their text.
struct ScriptLanguagePickerView: View {
    @Environment(LanguageSettingsService.self) private var languages

    var body: some View {
        List {
            Section {
                LanguageOptionRow(
                    title: String(localized: "Auto-detect"),
                    detail: String(localized: "Cue reads the language from what you write"),
                    isSelected: languages.scriptLanguage == nil,
                    identifier: "language.script.auto"
                ) {
                    languages.scriptLanguage = nil
                }
            }
            Section {
                ForEach(CueLanguage.allCases) { language in
                    LanguageOptionRow(
                        title: language.nativeName,
                        detail: language.label,
                        isSelected: languages.scriptLanguage == language,
                        identifier: "language.script.\(language.rawValue)"
                    ) {
                        languages.scriptLanguage = language
                    }
                }
            } footer: {
                Text("Write in any language, whatever language Cue is in. Changing this never translates a script.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Script Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack { ScriptLanguagePickerView() }
        .previewEnvironment()
}
#endif
