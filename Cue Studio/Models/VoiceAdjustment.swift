//
//  VoiceAdjustment.swift
//  Cue Studio
//

import Foundation

/// "Adjust" on a script that was written in the creator's voice: what didn't sound like them. Each
/// answer is a small, reversible change to the voice, applied to this script only or kept in the
/// profile.
nonisolated enum VoiceAdjustment: String, CaseIterable, Identifiable, Sendable {
    case tooFormal, tooMuchSlang, tooOverTheTop, notMyPhrase, tooLong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tooFormal: String(localized: "Too formal")
        case .tooMuchSlang: String(localized: "Too much slang")
        case .tooOverTheTop: String(localized: "Too over the top")
        case .notMyPhrase: String(localized: "“I don’t say that”")
        case .tooLong: String(localized: "Too long")
        }
    }

    /// What changes, in a line: "Slang · Some → Rarely".
    var change: String {
        switch self {
        case .tooFormal: String(localized: "Formality · Balanced → Casual")
        case .tooMuchSlang: String(localized: "Slang · Some → Rarely")
        case .tooOverTheTop: String(localized: "Energy · Warm → Calm")
        case .notMyPhrase: String(localized: "Phrases · Removed")
        case .tooLong: String(localized: "Sentences · Mixed → Short")
        }
    }

    /// The profile with this adjustment made. Only the voice changes; nothing is added past the
    /// limits the setup keeps.
    func applied(to profile: CreatorProfile) -> CreatorProfile {
        var profile = profile
        switch self {
        case .tooFormal:
            profile.sounds.removeAll { $0 == .professional }
            if !profile.sounds.contains(.casual) { profile.sounds.append(.casual) }
            if profile.vocabulary == .professional { profile.vocabulary = .simple }
        case .tooMuchSlang:
            if profile.vocabulary == .genZ { profile.vocabulary = .simple }
        case .tooOverTheTop:
            profile.sounds.removeAll { $0 == .energetic || $0 == .funny }
            if profile.sounds.isEmpty { profile.sounds = [.casual] }
        case .notMyPhrase:
            profile.phrases = []
        case .tooLong:
            if !profile.styles.contains(.shortSentences) { profile.styles.append(.shortSentences) }
        }
        return profile
    }

    /// All the chosen adjustments, one after the other.
    static func applying(_ adjustments: [VoiceAdjustment], to profile: CreatorProfile) -> CreatorProfile {
        adjustments.reduce(profile) { $1.applied(to: $0) }
    }
}
