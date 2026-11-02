//
//  CreatorProfileService+Inference.swift
//  Cue Studio
//

import Foundation

extension CreatorProfileService {
    // MARK: - What Cue noticed (the owner's item 6, 02/11/2026)

    /// "Yes" on something Cue noticed: it becomes the answer, as if the creator had picked it.
    func confirm(_ suggestion: VoiceInference.Suggestion) {
        switch suggestion {
        case .formats(let kinds, _):
            var updated = profile
            updated.formats = Array(kinds.prefix(VoiceLimits.formats))
            profile = updated
        case .reach(let platform, let length, _):
            var updated = profile
            updated.reach.platforms = [platform]
            if let length { updated.reach.length = length }
            profile = updated
        case .gender(let gender):
            setSpeakerGender(gender)
        }
    }
}
