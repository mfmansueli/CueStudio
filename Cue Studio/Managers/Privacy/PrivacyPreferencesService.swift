//
//  PrivacyPreferencesService.swift
//  Cue Studio
//

import Foundation

/// The two switches of Settings › Privacy & AI data. "On-device AI" is the master switch of every Apple Intelligence feature
/// (`ScriptWriting.isEnabled`); "Help improve Cue" is for anonymous usage numbers. Cue has no server and sends no usage
/// today, so that one only remembers the choice, off until the creator turns it on.
@MainActor
@Observable
final class PrivacyPreferencesService {
    var usesOnDeviceAI: Bool {
        didSet {
            defaults.set(usesOnDeviceAI, forKey: DefaultsKey.onDeviceAI)
            writer.isEnabled = usesOnDeviceAI
        }
    }

    var helpsImproveCue: Bool {
        didSet { defaults.set(helpsImproveCue, forKey: DefaultsKey.helpImproveCue) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let writer: ScriptWriting

    init(defaults: UserDefaults = .standard, writer: ScriptWriting) {
        self.defaults = defaults
        self.writer = writer
        let usesAI = defaults.object(forKey: DefaultsKey.onDeviceAI) as? Bool ?? true
        usesOnDeviceAI = usesAI
        helpsImproveCue = defaults.object(forKey: DefaultsKey.helpImproveCue) as? Bool ?? false
        writer.isEnabled = usesAI
    }
}
