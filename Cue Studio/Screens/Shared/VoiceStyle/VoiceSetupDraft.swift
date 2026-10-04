//
//  VoiceSetupDraft.swift
//  Cue Studio
//

import Foundation

/// The answers in the short voice setup, apart from its view: which steps are asked, what is picked,
/// the limits, and when saving is allowed. Only what the profile still lacks is asked; what the
/// creator already answered is kept and shown picked when the steps are all asked (editing).
struct VoiceSetupDraft: Equatable {
    /// Niches a creator can pick here, and tones: few, so the voice stays clear for the model
    /// (`CreatorVoice.summary` reads two sounds). A profile that already holds more keeps them.
    static let nicheLimit = VoiceLimits.topics
    static let soundLimit = VoiceLimits.tones

    let steps: [VoiceSetupStep]
    private(set) var role: CreatorRole?
    private(set) var niches: [Niche]
    private(set) var vocabulary: Vocabulary?
    private(set) var sounds: [VoiceSound]
    let nicheCap: Int
    let soundCap: Int
    /// An asked step is showing values an older build saved (maybe choices, maybe defaults): the setup
    /// asks the creator to confirm them, with nothing to pick again.
    let confirmsExistingValues: Bool

    /// - Parameter steps: what to ask; nil asks what the profile still lacks.
    init(profile: CreatorProfile, steps: [VoiceSetupStep]? = nil) {
        // A creator setting the voice up from scratch is also asked what kind of creator they are.
        let missing = profile.missingVoiceSteps
        self.steps = steps ?? (missing.contains(.niche) && !profile.hasAnswered(.role) ? [.role] + missing : missing)
        role = profile.role
        // A new profile's defaults are not answers, so nothing is shown picked; what the creator chose,
        // or an older build saved, is shown picked and can be confirmed as it is.
        niches = profile.hasAnswered(.niche) ? profile.niches : []
        vocabulary = profile.isChosen(.audience) ? profile.vocabulary : nil
        sounds = profile.isChosen(.tone) ? profile.sounds : []
        confirmsExistingValues = self.steps.contains { !profile.hasAnswered($0) && profile.isChosen($0) }
        nicheCap = max(Self.nicheLimit, niches.count)
        soundCap = max(Self.soundLimit, sounds.count)
    }

    // MARK: - Picking

    func isPicked(_ role: CreatorRole) -> Bool { self.role == role }
    func isPicked(_ niche: Niche) -> Bool { niches.contains(niche) }
    func isPicked(_ sound: VoiceSound) -> Bool { sounds.contains(sound) }
    func isPicked(_ vocabulary: Vocabulary) -> Bool { self.vocabulary == vocabulary }

    /// Whether one more niche (or sound) can be picked.
    var canAddNiche: Bool { niches.count < nicheCap }
    var canAddSound: Bool { sounds.count < soundCap }

    /// Picks or lets go. At the limit, an unpicked option is ignored. Returns whether anything changed.
    @discardableResult
    mutating func toggle(_ niche: Niche) -> Bool {
        if let index = niches.firstIndex(of: niche) {
            niches.remove(at: index)
            return true
        }
        guard canAddNiche else { return false }
        niches.append(niche)
        return true
    }

    @discardableResult
    mutating func toggle(_ sound: VoiceSound) -> Bool {
        if let index = sounds.firstIndex(of: sound) {
            sounds.remove(at: index)
            return true
        }
        guard canAddSound else { return false }
        sounds.append(sound)
        return true
    }

    mutating func choose(_ role: CreatorRole) {
        self.role = role
    }

    mutating func choose(_ vocabulary: Vocabulary) {
        self.vocabulary = vocabulary
    }

    // MARK: - Saving

    /// Every step that is asked has an answer.
    var canSave: Bool {
        steps.allSatisfy { step in
            switch step {
            case .role: true
            case .niche: !niches.isEmpty
            case .audience: vocabulary != nil
            case .tone: !sounds.isEmpty
            }
        }
    }

    /// Writes the answers into the profile, through the same service and fields as Profile, and turns
    /// the voice on. Only the steps that were asked are written.
    @MainActor
    func save(to service: CreatorProfileService) {
        guard canSave else { return }
        service.saveVoiceSetup(
            role: steps.contains(.role) ? role : nil,
            niches: steps.contains(.niche) ? niches : nil,
            vocabulary: steps.contains(.audience) ? vocabulary : nil,
            sounds: steps.contains(.tone) ? sounds : nil
        )
    }
}
