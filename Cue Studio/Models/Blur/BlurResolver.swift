//
//  BlurResolver.swift
//  Cue Studio
//

import Foundation

/// Which Blur areas a frame of some footage draws, and where (`BlurShown`). Pure: the compositor asks it for every frame of the
/// main video (by the recording a clip plays and that clip's second of its file) and of each photo or video over the take, and
/// the cover for its frame, so they all hide the same things.
nonisolated enum BlurResolver {
    /// The areas on the frame at `time` (seconds of its file) of the recording `id` (nil: the take). A reversed clip's file
    /// shows another recording read backwards, and a frozen frame another one's second: their areas follow.
    static func shown(_ regions: [BlurRegion], onRecording id: UUID?, at time: TimeInterval, sources: [ClipSource]) -> [BlurShown] {
        guard !regions.isEmpty else { return [] }
        var result = direct(regions, onRecording: id, at: time)
        if let id, let source = sources.first(where: { $0.id == id }) {
            if let reversal = source.reversal {
                result += direct(regions, onRecording: reversal.sourceID, at: reversal.span.end - time)
            }
            if let still = source.still {
                result += direct(regions, onRecording: still.sourceID, at: still.time)
            }
        }
        return result
    }

    /// The areas on the photo or video over the take `id`, at `time` (seconds of its file; a photo's areas always show).
    static func shown(_ regions: [BlurRegion], onMedia id: UUID, at time: TimeInterval, isPhoto: Bool) -> [BlurShown] {
        regions.compactMap { region in
            guard region.target.mediaID == id, region.covers(time, onPhoto: isPhoto) else { return nil }
            return BlurShown(region, at: isPhoto ? region.span.start : time)
        }
    }

    private static func direct(_ regions: [BlurRegion], onRecording id: UUID?, at time: TimeInterval) -> [BlurShown] {
        regions.compactMap { region in
            guard !region.target.isMedia, region.target.recordingID == id, region.span.contains(time) else { return nil }
            return BlurShown(region, at: time)
        }
    }
}
