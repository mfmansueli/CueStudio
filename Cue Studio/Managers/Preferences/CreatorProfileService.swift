//
//  CreatorProfileService.swift
//  Cue Studio
//

import Foundation

/// The creator's profile ("Creator DNA") and defaults. Stored on the device only.
@MainActor
@Observable
final class CreatorProfileService {
    var profile: CreatorProfile {
        didSet {
            guard let data = try? JSONEncoder().encode(profile) else { return }
            defaults.set(data, forKey: DefaultsKey.creatorProfile)
        }
    }

    private let defaults: UserDefaults

    /// A "+ Something else" answer was typed (`VoiceTypedAnswerEvent`, never the text): `AppServices` sends it only with "Help improve Cue" on.
    @ObservationIgnored var reportTypedAnswer: (VoiceTypedAnswerEvent) -> Void = { _ in }

    /// Whose turn it is among the catchphrases (`CatchphraseRotation`): the scripts written with them so far.
    private(set) var catchphraseTurn: Int {
        didSet { defaults.set(catchphraseTurn, forKey: DefaultsKey.catchphraseTurn) }
    }

    /// A script was sent with the current turn's catchphrases: the next one gets the others.
    func advanceCatchphraseTurn() {
        guard CatchphraseRotation.rotates(profile.phrases) else { return }
        catchphraseTurn &+= 1
    }

    /// The catchphrases the next script is offered.
    var nextCatchphrases: [String] { CatchphraseRotation.phrases(profile.phrases, at: catchphraseTurn) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        catchphraseTurn = defaults.integer(forKey: DefaultsKey.catchphraseTurn)
        if let data = defaults.data(forKey: DefaultsKey.creatorProfile),
           let stored = try? JSONDecoder().decode(CreatorProfile.self, from: data) {
            profile = stored
        } else {
            profile = CreatorProfile()
        }
    }

    // MARK: - Actions

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
    /// yet: nothing is answered, so the questions have to be answered first (`answer(_:with:)`).
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
}
