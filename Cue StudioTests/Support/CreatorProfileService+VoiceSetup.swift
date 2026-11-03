//
//  CreatorProfileService+VoiceSetup.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
extension CreatorProfileService {
    /// A creator who already answered My Cue Voice: these answers in the profile's own fields, marked as theirs, with the voice
    /// on. A step passed as nil (or an empty list) is left as it was.
    func saveVoiceSetup(role: CreatorRole? = nil, niches: [Niche]? = nil, vocabulary: Vocabulary? = nil, sounds: [VoiceSound]? = nil) {
        var updated = profile
        if let role {
            // As the setup saves it: a kind of creator out of the long list, with its broad role (a role alone is asked again).
            updated.role = role
            updated.creatorKind = CreatorKind.all.first { $0.role == role }?.id
        }
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
