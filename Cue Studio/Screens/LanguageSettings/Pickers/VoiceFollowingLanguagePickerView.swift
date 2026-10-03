//
//  VoiceFollowingLanguagePickerView.swift
//  Cue Studio
//

import SwiftUI

/// Language & Region › Voice Following Language. Each language shows what this device reports for
/// it; one it can't listen in stays listed with a warning instead of pretending to work.
struct VoiceFollowingLanguagePickerView: View {
    @Environment(LanguageSettingsService.self) private var languages
    @Environment(SpeechRecognitionManager.self) private var speech

    @State private var viewModel = LanguageSettingsViewModel()

    var body: some View {
        List {
            Section {
                LanguageOptionRow(
                    title: String(localized: "Same as script"),
                    detail: String(localized: "Listens in each script's language"),
                    isSelected: languages.voiceFollowingLanguage == .sameAsScript,
                    identifier: "language.voice.script"
                ) {
                    languages.voiceFollowingLanguage = .sameAsScript
                }
            } footer: {
                Text("Recommended. A script in Portuguese is followed in Portuguese, one in English in English.")
            }
            Section {
                ForEach(CueLanguage.allCases) { language in
                    let availability = viewModel.availability(of: language)
                    LanguageOptionRow(
                        title: language.nativeName,
                        detail: language.label,
                        status: viewModel.statusLabel(for: language),
                        statusIsWarning: availability == .unavailable,
                        isSelected: languages.voiceFollowingLanguage == .language(language),
                        identifier: "language.voice.\(language.rawValue)"
                    ) {
                        languages.voiceFollowingLanguage = .language(language)
                    }
                }
            } footer: {
                Text("Cue listens on this device with Apple's speech recognition. Nothing is sent to a server. Cue never guesses the language you speak, and never switches to another one.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Voice Following")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAvailability(using: speech) }
    }
}

#if DEBUG
#Preview {
    NavigationStack { VoiceFollowingLanguagePickerView() }
        .previewEnvironment()
}
#endif
