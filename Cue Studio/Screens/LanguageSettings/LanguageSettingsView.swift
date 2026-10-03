//
//  LanguageSettingsView.swift
//  Cue Studio
//

import SwiftUI

/// Profile › Settings › Language & Region: the interface, Voice Following and scripts, each with its
/// own language and its own explanation, so it's clear they don't move together.
struct LanguageSettingsView: View {
    @Environment(LanguageSettingsService.self) private var languages
    @Environment(SpeechRecognitionManager.self) private var speech

    @State private var viewModel = LanguageSettingsViewModel()

    var body: some View {
        List {
            Section {
                NavigationLink(value: ProfileRoute.appLanguage) {
                    row(title: String(localized: "App Language"), value: languages.appLanguageLabel)
                }
                .accessibilityIdentifier("language.appLanguageRow")
            } footer: {
                Text("Controls the language of Cue's interface.")
            }
            Section {
                NavigationLink(value: ProfileRoute.voiceFollowingLanguage) {
                    row(title: String(localized: "Voice Following Language"), value: languages.voiceFollowingLanguage.label)
                }
                .accessibilityIdentifier("language.voiceFollowingRow")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Controls the language Cue listens for while you speak.")
                    if let language = languages.voiceFollowingLanguage.language {
                        voiceStatus(for: language)
                    } else {
                        Text("Listens in each script's language.")
                    }
                }
            }
            Section {
                NavigationLink(value: ProfileRoute.scriptLanguage) {
                    row(title: String(localized: "Script Language"), value: languages.scriptLanguageLabel)
                }
                .accessibilityIdentifier("language.scriptLanguageRow")
            } footer: {
                Text("Controls the language of new scripts. To change one script, use Language in its More menu. Scripts are never translated.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Language & Region")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAvailability(using: speech) }
    }

    private func row(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private func voiceStatus(for language: CueLanguage) -> some View {
        let availability = viewModel.availability(of: language)
        return Text(availability == .unavailable
            ? String(localized: "\(language.label) isn't available for Voice Following on this device. The text moves while you speak instead.")
            : "\(language.label) · \(viewModel.statusLabel(for: language))")
            .foregroundStyle(availability == .unavailable ? Palette.warn : Palette.ink2)
            .accessibilityIdentifier("language.voiceFollowingStatus")
    }
}

#if DEBUG
#Preview {
    NavigationStack { LanguageSettingsView() }
        .previewEnvironment()
}
#endif
