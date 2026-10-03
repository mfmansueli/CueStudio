//
//  LanguageSettingsViewModel.swift
//  Cue Studio
//

import Foundation

/// Which languages Voice Following can listen in on this device, asked of the speech framework
/// once per screen. Nothing is assumed: a language shows as available only when the device says so.
@MainActor
@Observable
final class LanguageSettingsViewModel {
    private(set) var availability: [CueLanguage: SpeechLanguageAvailability] = [:]
    private(set) var isChecking = false

    func loadAvailability(using speech: SpeechTranscribing) async {
        guard availability.isEmpty, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        for language in CueLanguage.allCases {
            let result = await speech.availability(of: language)
            guard !Task.isCancelled else { return }
            availability[language] = result
        }
    }

    func availability(of language: CueLanguage) -> SpeechLanguageAvailability? {
        availability[language]
    }

    /// "Ready on this iPhone", or "Checking…" until the device answered.
    func statusLabel(for language: CueLanguage) -> String {
        availability[language]?.label ?? String(localized: "Checking…")
    }
}
