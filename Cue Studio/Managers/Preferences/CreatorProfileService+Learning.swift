//
//  CreatorProfileService+Learning.swift
//  Cue Studio
//

import Foundation

extension CreatorProfileService {
    // MARK: - What Cue learned (the owner's item 11, 02/11/2026)

    /// "Adjust" kept in the profile: the voice with `adjustments` made, one after the other, each change listed in "What Cue learned" with what it
    /// changed (one that changes nothing isn't listed). The oldest change goes past `VoiceLearning.limit`; what it changed stays.
    /// - Returns: the profile as it is now.
    @discardableResult
    func keepAdjustments(_ adjustments: [VoiceAdjustment], cause: TooLongCause? = nil, scriptSeconds: TimeInterval? = nil) -> CreatorProfile {
        var updated = profile
        for adjustment in adjustments {
            let before = VoiceLearning.Snapshot(updated)
            updated = adjustment.applied(to: updated, cause: cause, scriptSeconds: scriptSeconds)
            let learning = VoiceLearning(
                adjustment: adjustment.rawValue, cause: adjustment == .tooLong ? cause?.rawValue : nil,
                before: before, after: VoiceLearning.Snapshot(updated)
            )
            if learning.changesSomething { updated.learned.append(learning) }
        }
        updated.learned = Array(updated.learned.suffix(VoiceLearning.limit))
        profile = updated
        return updated
    }

    /// Takes a change back: what it changed returns to what it was (unless the creator changed it since), and the next scripts don't use it.
    func forget(_ learning: VoiceLearning) {
        var updated = learning.undone(in: profile)
        updated.learned.removeAll { $0.id == learning.id }
        profile = updated
    }
}
