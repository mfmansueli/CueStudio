//
//  CreatorProfileService.swift
//  Cue Studio
//

import Foundation

/// The creator's profile ("Creator DNA") and defaults. Stored on the device only.
@MainActor
@Observable
final class CreatorProfileService {
    static let maxPhraseLength = 40

    var profile: CreatorProfile {
        didSet {
            guard let data = try? JSONEncoder().encode(profile) else { return }
            defaults.set(data, forKey: DefaultsKey.creatorProfile)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: DefaultsKey.creatorProfile),
           let stored = try? JSONDecoder().decode(CreatorProfile.self, from: data) {
            profile = stored
        } else {
            profile = CreatorProfile()
        }
    }

    // MARK: - Actions

    func toggleNiche(_ niche: Niche) {
        if let index = profile.niches.firstIndex(of: niche) {
            profile.niches.remove(at: index)
        } else {
            profile.niches.append(niche)
        }
    }

    /// Keeps at least one sound: an empty voice would tell the AI nothing. Choosing one is the
    /// creator answering "How do you talk?"; the first time, it starts from nothing, so the default
    /// tones of a new profile never ride along with the one picked.
    func toggleSound(_ sound: VoiceSound) {
        var updated = profile
        if !updated.isChosen(.tone) { updated.sounds = [] }
        if let index = updated.sounds.firstIndex(of: sound) {
            guard updated.sounds.count > 1 else { return }
            updated.sounds.remove(at: index)
        } else {
            updated.sounds.append(sound)
        }
        updated.confirm(.tone)
        profile = updated
    }

    /// Choosing a vocabulary is the creator answering "Who do you talk to?", even when it is the default one.
    func setVocabulary(_ vocabulary: Vocabulary) {
        var updated = profile
        updated.vocabulary = vocabulary
        updated.confirm(.audience)
        profile = updated
    }

    func toggleStyle(_ style: VoiceStyle) {
        if let index = profile.styles.firstIndex(of: style) {
            profile.styles.remove(at: index)
        } else {
            profile.styles.append(style)
        }
    }

    /// Adds a catchphrase. Returns false when it is empty or already there.
    @discardableResult
    func addPhrase(_ phrase: String) -> Bool {
        let cleaned = String(phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            .prefix(Self.maxPhraseLength))
        guard !cleaned.isEmpty,
              !profile.phrases.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame })
        else { return false }
        profile.phrases.append(cleaned)
        return true
    }

    func removePhrase(_ phrase: String) {
        profile.phrases.removeAll { $0 == phrase }
    }

    // MARK: - Write in my voice

    /// The one state behind every "Write in my voice" switch (the Prompt card, Generate, Profile):
    /// on when the creator asked for it and has answered something the AI can use. The defaults a new
    /// profile starts with are not answers, so the voice is never applied from them; with an answer, what
    /// is known is used and the rest is left out (`CreatorProfile.canWriteInMyVoice`).
    var writesInMyVoice: Bool { profile.usesVoiceInAI && profile.canWriteInMyVoice }

    /// Turns the voice off or on. Returns false, and changes nothing, when it can't be turned on
    /// yet: nothing is answered, so the setup has to run first (`saveVoiceSetup`).
    @discardableResult
    func setWritesInMyVoice(_ isOn: Bool) -> Bool {
        if isOn, !profile.canWriteInMyVoice { return false }
        profile.usesVoiceInAI = isOn
        return true
    }

    /// The first flight's picks: the topics (known ones feed My Cue Voice; typed ones are kept for the
    /// universe) and the platform new scripts start for. Nothing is changed when nothing was picked.
    func applyFirstFlight(niches: [Niche], customTopics: [String], platform: Platform) {
        var updated = profile
        if !niches.isEmpty { updated.niches = niches }
        if !customTopics.isEmpty { updated.customTopics = customTopics }
        if Platform.primary.contains(platform) { updated.defaultPlatform = platform }
        profile = updated
    }

    /// Saves the answers of the short setup into the same profile fields Profile edits, marks them
    /// as the creator's own and turns the voice on. A step passed as nil (or an empty list) is left as it was.
    func saveVoiceSetup(role: CreatorRole? = nil, niches: [Niche]? = nil, vocabulary: Vocabulary? = nil, sounds: [VoiceSound]? = nil) {
        var updated = profile
        if let role { updated.role = role }
        if let niches, !niches.isEmpty { updated.niches = niches }
        if let vocabulary {
            updated.vocabulary = vocabulary
            updated.confirm(.audience)
        }
        if let sounds, !sounds.isEmpty {
            updated.sounds = sounds
            updated.confirm(.tone)
        }
        updated.usesVoiceInAI = true
        profile = updated
    }
}
