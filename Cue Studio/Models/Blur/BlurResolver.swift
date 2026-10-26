//
//  BlurResolver.swift
//  Cue Studio
//

import Foundation

/// Which Blur areas a frame of some footage draws, and where (`BlurShown`). Pure: the compositor asks it for every frame of the
/// main video (by the recording a clip plays and that clip's second of its file) and of each photo or video over the take, and
/// the cover for its frame, so they all hide the same things.
nonisolated enum BlurResolver {
    /// A frame either side of an area's ends still counts (the last frame of a reversed clip is the first of its stretch).
    static let edge: TimeInterval = 1.0 / 60

    /// The areas on the frame at `time` (seconds of its file) of the recording `id` (nil: the take). A reversed clip's file
    /// shows another recording read backwards, and a frozen frame another one's second: their areas follow. `reach` widens
    /// every area's stretch: the other side of a transition plays frames from just past its clip's ends, which an area made on
    /// that clip must hide too (a face fading in through a dissolve is a face shown).
    static func shown(
        _ regions: [BlurRegion], onRecording id: UUID?, at time: TimeInterval, sources: [ClipSource], reach: TimeInterval = 0
    ) -> [BlurShown] {
        guard !regions.isEmpty else { return [] }
        var result = direct(regions, onRecording: id, at: time, reach: reach)
        if let id, let source = sources.first(where: { $0.id == id }) {
            if let reversal = source.reversal {
                result += direct(regions, onRecording: reversal.sourceID, at: reversal.span.end - time, reach: reach)
            }
            if let still = source.still {
                result += direct(regions, onRecording: still.sourceID, at: still.time, reach: reach)
            }
        }
        return result
    }

    /// The areas on the photo or video over the take `id`, at `time` (seconds of its file; a photo's areas always show).
    static func shown(_ regions: [BlurRegion], onMedia id: UUID, at time: TimeInterval, isPhoto: Bool) -> [BlurShown] {
        regions.compactMap { region in
            guard region.target.mediaID == id,
                  isPhoto || (time >= region.span.start - edge && time <= region.span.end + edge) else { return nil }
            return BlurShown(region, at: isPhoto ? region.span.start : time)
        }
    }

    private static func direct(_ regions: [BlurRegion], onRecording id: UUID?, at time: TimeInterval, reach: TimeInterval) -> [BlurShown] {
        let margin = max(edge, reach)
        return regions.compactMap { region in
            guard !region.target.isMedia, region.target.recordingID == id,
                  time >= region.span.start - margin, time <= region.span.end + margin else { return nil }
            return BlurShown(region, at: time)
        }
    }
}
