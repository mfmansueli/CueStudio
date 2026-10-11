//
//  CreatorProfileService+DraftLearning.swift
//  Cue Studio
//

import Foundation

extension CreatorProfileService {
    // MARK: - Learning from what the creator records

    /// A script Cue drafted and the creator made their own, then recorded (`DraftLearningService`): its opening is kept as one of the
    /// last `VoiceLimits.approvedSamples` examples of how they write, beside the "Sounds like me" ones (the oldest goes). Unlike "Sounds
    /// like me" it isn't an approval of Cue's words, so it doesn't count toward the meter's approvals.
    /// - Returns: the example kept, or nil when the text can't be learned from or is already there.
    @discardableResult
    func learnFromRecordedScript(_ script: String) -> VoiceExample? {
        guard let sample = Self.approvedSample(from: script),
              !profile.approvedSamples.contains(where: { VoiceTextValidator.key($0.text) == VoiceTextValidator.key(sample) }) else { return nil }
        let example = VoiceExample(text: sample, source: String(localized: "Your edits"))
        var updated = profile
        updated.approvedSamples.append(example)
        updated.approvedSamples = Array(updated.approvedSamples.suffix(VoiceLimits.approvedSamples))
        profile = updated
        return example
    }
}
