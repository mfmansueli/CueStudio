//
//  TakeEdit+Voice.swift
//  Cue Studio
//

import Foundation

/// Studio Voice over a montage: which recordings it treats, how each one is treated, and whether their levels are evened out.
nonisolated extension TakeEdit {
    /// The recordings the edit plays, the take first (nil), then the others in the order they were added.
    var playedRecordingIDs: [UUID?] {
        [nil] + playedSources.map(\.id)
    }

    /// Whether Studio Voice treats the recording `sourceID` (nil: the take).
    func treatsVoice(of sourceID: UUID?) -> Bool {
        voiceReach.treats(sourceID)
    }

    /// How the recording `sourceID` is treated: the take with its own volume, another recording with the same levels at its own
    /// volume (each clip's volume is set on the clip). Untouched when it isn't treated.
    func voiceProcessing(for sourceID: UUID?) -> VoiceProcessing {
        guard let sourceID else { return voiceProcessing }
        let levels = voiceProcessing
        guard treatsVoice(of: sourceID) else { return levels.untreated.withVolume(1) }
        return VoiceProcessing(
            version: max(2, levels.version), volume: 1, enhancesVoice: false, reducesNoise: false,
            enhancement: levels.enhancement, noise: levels.noise
        )
    }

    /// The played recordings Studio Voice treats.
    var treatedRecordingIDs: [UUID?] {
        playedRecordingIDs.filter(treatsVoice(of:))
    }

    /// Levels are evened out once there are at least two treated recordings to even out.
    var evensOutLevels: Bool {
        evensOutVoices && treatedRecordingIDs.count > 1
    }
}
