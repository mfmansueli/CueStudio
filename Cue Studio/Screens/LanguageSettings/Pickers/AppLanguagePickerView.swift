//
//  AppLanguagePickerView.swift
//  Cue Studio
//

import SwiftUI

/// Language & Region › App Language. Only Cue's interface changes: scripts, Voice Following and
/// the iPhone keep their languages.
struct AppLanguagePickerView: View {
    @Environment(LanguageSettingsService.self) private var languages
    @Environment(ToastService.self) private var toast

    var body: some View {
        List {
            Section {
                LanguageOptionRow(
                    title: String(localized: "iPhone Language"),
                    detail: String(localized: "Cue follows the language your iPhone is in"),
                    isSelected: languages.appLanguage == nil,
                    identifier: "language.app.system"
                ) {
                    select(nil)
                }
            }
            Section {
                ForEach(CueLanguage.allCases) { language in
                    LanguageOptionRow(
                        title: language.nativeName,
                        detail: language.label,
                        isSelected: languages.appLanguage == language,
                        identifier: "language.app.\(language.rawValue)"
                    ) {
                        select(language)
                    }
                }
            } footer: {
                Text("Your scripts stay exactly as you wrote them. Voice Following and Script Language keep their own settings.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("App Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ language: CueLanguage?) {
        guard languages.appLanguage != language else { return }
        languages.appLanguage = language
        // Read after the switch, so the confirmation is already in the new language.
        toast.show(String(localized: "Cue is now in \(languages.appLanguageLabel)"))
    }
}

#if DEBUG
#Preview {
    NavigationStack { AppLanguagePickerView() }
        .previewEnvironment()
}
#endif
