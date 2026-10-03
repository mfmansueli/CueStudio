//
//  CompositionShape.swift
//  Cue Studio
//

import AVFoundation

/// What a composition is made of: its tracks and, on each, which part of which file plays when.
/// Two builds of an edit with the same shape differ only in what is drawn on the frames and how
/// the sound is mixed (`AVVideoComposition`, `AVAudioMix`), so the preview keeps its item and
/// takes the new ones instead of swapping items, which blanks the picture for a moment.
nonisolated struct CompositionShape: Equatable {
    private struct Piece: Equatable {
        let url: URL?
        let sourceTrackID: CMPersistentTrackID
        let source: CMTimeRange
        let target: CMTimeRange
        let isEmpty: Bool
    }

    private struct Track: Equatable {
        let id: CMPersistentTrackID
        let mediaType: AVMediaType
        let pieces: [Piece]
    }

    private let tracks: [Track]

    /// Nil for an asset that isn't a composition.
    init?(of asset: AVAsset) {
        guard let composition = asset as? AVComposition else { return nil }
        tracks = composition.tracks.map { track in
            Track(id: track.trackID, mediaType: track.mediaType, pieces: track.segments.map { segment in
                Piece(
                    url: segment.sourceURL, sourceTrackID: segment.sourceTrackID,
                    source: segment.timeMapping.source, target: segment.timeMapping.target, isEmpty: segment.isEmpty
                )
            })
        }
    }
}
