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
    var change: String { change(cause: nil) }

    /// What changes, in a line, with what was too long (`cause`) when "Too long" is kept in the profile.
    func change(cause: TooLongCause?) -> String {
        switch self {
        case .tooFormal: String(localized: "Formality · Balanced → Casual")
        case .tooMuchSlang: String(localized: "Slang · Some → Rarely")
        case .tooOverTheTop: String(localized: "Energy · Warm → Calm")
        case .notMyPhrase: String(localized: "Phrases · Removed")
        case .tooLong:
            switch cause {
            case .video?: String(localized: "Video length · Shorter")
            case .ideas?: String(localized: "Ideas · One per video")
            case .sentences?, nil: String(localized: "Sentences · Mixed → Short")
            }
        }
    }

    /// The profile with this adjustment made. Only the voice changes; nothing is added past the
    /// limits the setup keeps.
    /// - Parameters:
    ///   - cause: what was too long, for "Too long" (nil: the sentences, as for this script only).
    ///   - scriptSeconds: how long the script runs, which a usual length never answered steps down from (`TooLongCause.video`).
    func applied(to profile: CreatorProfile, cause: TooLongCause? = nil, scriptSeconds: TimeInterval? = nil) -> CreatorProfile {
        var profile = profile
        switch self {
        case .tooFormal:
            profile.sounds.removeAll { $0 == .professional }
            if !profile.sounds.contains(.casual) { profile.sounds.append(.casual) }
            if profile.vocabulary == .professional { profile.vocabulary = .simple }
            if profile.style.words == .expertTerms { profile.style.words = .plain }
        case .tooMuchSlang:
            if profile.vocabulary == .genZ { profile.vocabulary = .simple }
            if profile.style.words == .someSlang { profile.style.words = .plain }
        case .tooOverTheTop:
            profile.sounds.removeAll { $0 == .energetic || $0 == .funny }
            if profile.sounds.isEmpty { profile.sounds = [.casual] }
            if profile.style.energy == .high { profile.style.energy = .calm }
        case .notMyPhrase:
            profile.phrases = []
        case .tooLong:
            profile = Self.shortened(profile, cause: cause, scriptSeconds: scriptSeconds)
        }
        return profile
    }

    /// "Too long": what was too long made shorter.
    private static func shortened(_ profile: CreatorProfile, cause: TooLongCause?, scriptSeconds: TimeInterval?) -> CreatorProfile {
        var profile = profile
        switch cause {
        case .video?:
            // What Auto aims at (`ScriptRequestFactory.targetRange`): one step under the usual length, or under this script's when it was never said.
            if let usual = profile.reach.length ?? scriptSeconds.map(VideoLength.init(containing:)) { profile.reach.length = usual.shorter }
        case .ideas?:
            profile.style.oneIdea = true
        case .sentences?, nil:
            if !profile.styles.contains(.shortSentences) { profile.styles.append(.shortSentences) }
            // What the prompt reads is the answer to "Short sentences or longer ones?", not the legacy styles.
            if profile.style.sentences != nil { profile.style.sentences = .short }
        }
        return profile
    }

    /// All the chosen adjustments, one after the other.
    static func applying(
        _ adjustments: [VoiceAdjustment], to profile: CreatorProfile, cause: TooLongCause? = nil, scriptSeconds: TimeInterval? = nil
    ) -> CreatorProfile {
        adjustments.reduce(profile) { $1.applied(to: $0, cause: cause, scriptSeconds: scriptSeconds) }
    }
}
