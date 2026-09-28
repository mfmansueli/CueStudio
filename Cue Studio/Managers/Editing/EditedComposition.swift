//
//  EditedComposition.swift
//  Cue Studio
//

import AVFoundation

/// A take with its Quick edit applied, ready to play or export: the timeline's pieces joined in
/// order, the processed sound (dipped for a moment at each cut so it never clicks), and a video
/// composition that crops, adjusts and overlays every frame.
///
/// Transitions (`TransitionWindow`) never change the length. A fade darkens the frames and the
/// sound around its cut. A dissolve reads a second video track that holds, around each dissolving
/// cut, the other side of it from the recording (the incoming piece before the cut, the outgoing
/// one after it), and the compositor blends the two.
nonisolated struct EditedComposition: @unchecked Sendable {
    /// How long the sound fades out and back in around a cut that removed something.
    static let cutFade: TimeInterval = 0.012

    let asset: AVMutableComposition
    let videoComposition: AVVideoComposition
    /// Nil when the take has no sound.
    let audioMix: AVAudioMix?

    struct Options: Sendable {
        var burnsInCaptions: Bool
        /// Height of the output's short side in pixels (1080 or 2160); nil keeps the recording's.
        var shortSide: CGFloat?
    }

    /// A volume ramp on the edited timeline.
    struct Fade: Hashable, Sendable {
        var start: TimeInterval
        var duration: TimeInterval
        var fromVolume: Float
        var toVolume: Float
    }

    enum BuildError: Error {
        case noVideoTrack
    }

    /// `processedAudio` replaces the recording's sound when the Audio tool changed it.
    static func build(source: URL, edit: TakeEdit, processedAudio: URL?, options: Options) async throws -> EditedComposition {
        let asset = AVURLAsset(url: source)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw BuildError.noVideoTrack }
        let (naturalSize, transform, frameRate) = try await videoTrack.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let audioAsset = processedAudio.map { AVURLAsset(url: $0) } ?? asset
        let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first

        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BuildError.noVideoTrack
        }
        let audio = audioTrack == nil ? nil : composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for span in edit.keptSpans {
            let range = CMTimeRange(
                start: CMTime(seconds: span.start, preferredTimescale: 600),
                duration: CMTime(seconds: span.duration, preferredTimescale: 600)
            )
            try video.insertTimeRange(range, of: videoTrack, at: cursor)
            if let audio, let audioTrack {
                try? audio.insertTimeRange(range, of: audioTrack, at: cursor)
            }
            cursor = cursor + range.duration
        }

        let windows = TransitionWindow.windows(in: edit.timeline)
        var dissolves = windows.filter { $0.transition == .dissolve }
        var blendTrack = dissolves.isEmpty ? nil : composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        if let track = blendTrack, (try? insertOtherSides(of: dissolves, from: videoTrack, into: track)) == nil {
            // The recording can't give the other sides: the cuts stay hard rather than failing.
            composition.removeTrack(track)
            blendTrack = nil
            dissolves = []
        }

        // The upright frame, the crop inside it, and the output size.
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let uprightSize = CGSize(width: abs(upright.width), height: abs(upright.height))
        let cropTopLeft = CropMath.crop(in: uprightSize, aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset)
        // Core Image measures y from the bottom.
        let crop = CGRect(x: cropTopLeft.minX, y: uprightSize.height - cropTopLeft.maxY, width: cropTopLeft.width, height: cropTopLeft.height)
        let renderSize = outputSize(for: crop.size, shortSide: options.shortSide)

        var overlays: [FrameOverlay] = []
        if options.burnsInCaptions, edit.showsCaptions {
            overlays += OverlayRenderer.captions(edit.editedCaptions, style: edit.captionStyle, position: edit.captionPosition, frame: crop.size)
        }
        let fadeWindows = windows.filter { $0.transition == .fade }
        let outputScale = crop.width > 0 ? renderSize.width / crop.width : 1
        let instructions = instructionRanges(for: dissolves, duration: cursor).map { stretch in
            CompositionInstruction(
                timeRange: stretch.range,
                trackID: video.trackID,
                blendTrackID: stretch.dissolve == nil ? nil : blendTrack?.trackID,
                transform: transform,
                crop: crop,
                edit: edit,
                overlays: overlays,
                outputScale: outputScale,
                dissolve: stretch.dissolve,
                fades: fadeWindows
            )
        }
        let configuration = AVVideoComposition.Configuration(
            customVideoCompositorClass: CueVideoCompositor.self,
            frameDuration: CMTime(value: 1, timescale: CMTimeScale(max(24, frameRate.rounded()))),
            instructions: instructions,
            renderScale: 1,
            renderSize: renderSize
        )
        return EditedComposition(
            asset: composition,
            videoComposition: AVVideoComposition(configuration: configuration),
            audioMix: audio.map { audioMix(for: $0, fades: fades(for: edit.timeline)) }
        )
    }

    /// The crop at the requested quality, with even dimensions. Never upscaled.
    static func outputSize(for crop: CGSize, shortSide: CGFloat?) -> CGSize {
        guard let shortSide, crop.width > 0, crop.height > 0 else {
            return CGSize(width: CropMath.even(crop.width), height: CropMath.even(crop.height))
        }
        let scale = min(1, shortSide / min(crop.width, crop.height))
        return CGSize(width: CropMath.even(crop.width * scale), height: CropMath.even(crop.height * scale))
    }

    // MARK: - Transitions

    /// Fills the blend track: around each dissolving cut, the other side of it from the recording.
    /// Before the cut the main track still shows the outgoing piece, so the blend track shows the
    /// incoming one from just before its start; after the cut, the outgoing one running on past
    /// its end. Empty everywhere else.
    private static func insertOtherSides(
        of dissolves: [TransitionWindow], from source: AVAssetTrack, into track: AVMutableCompositionTrack
    ) throws {
        var filled = CMTime.zero
        for window in dissolves {
            let half = CMTime(seconds: window.halfDuration, preferredTimescale: 600)
            let start = CMTimeMaximum(CMTime(seconds: window.start, preferredTimescale: 600), filled)
            if CMTimeCompare(start, filled) > 0 { track.insertEmptyTimeRange(CMTimeRange(start: filled, end: start)) }
            let incoming = CMTime(seconds: window.incomingStart - window.halfDuration, preferredTimescale: 600)
            try track.insertTimeRange(CMTimeRange(start: incoming, duration: half), of: source, at: start)
            let outgoing = CMTime(seconds: window.outgoingEnd, preferredTimescale: 600)
            try track.insertTimeRange(CMTimeRange(start: outgoing, duration: half), of: source, at: start + half)
            filled = start + half + half
        }
    }

    /// The edit cut into stretches the compositor renders the same way: each dissolve on its own
    /// (reading both tracks), the rest from the main track alone. They follow on without gaps
    /// from the start to `duration`.
    static func instructionRanges(
        for dissolves: [TransitionWindow], duration: CMTime
    ) -> [(range: CMTimeRange, dissolve: TransitionWindow?)] {
        var ranges: [(range: CMTimeRange, dissolve: TransitionWindow?)] = []
        var from = CMTime.zero
        for window in dissolves {
            let start = CMTimeMaximum(CMTime(seconds: window.start, preferredTimescale: 600), from)
            let end = CMTimeMinimum(CMTime(seconds: window.end, preferredTimescale: 600), duration)
            guard CMTimeCompare(end, start) > 0 else { continue }
            if CMTimeCompare(start, from) > 0 { ranges.append((CMTimeRange(start: from, end: start), nil)) }
            ranges.append((CMTimeRange(start: start, end: end), window))
            from = end
        }
        if CMTimeCompare(duration, from) > 0 || ranges.isEmpty {
            ranges.append((CMTimeRange(start: from, end: CMTimeMaximum(from, duration)), nil))
        }
        return ranges
    }

    // MARK: - Sound at the cuts

    /// A short dip in the sound at each seam where something was removed, so joining two
    /// waveforms mid-cycle never clicks. Cuts that removed nothing play straight through. A fade
    /// takes the sound down to silence and back with the picture instead.
    static func fades(for timeline: EditTimeline) -> [Fade] {
        var dips: [Int: TransitionWindow] = [:]
        for window in TransitionWindow.windows(in: timeline) where window.transition == .fade {
            dips[window.join] = window
        }
        var fades: [Fade] = []
        var elapsed: TimeInterval = 0
        for (index, segment) in timeline.segments.enumerated() {
            let end = elapsed + segment.duration
            let length = min(cutFade, segment.duration / 2)
            if let dip = dips[index] {
                fades.append(Fade(start: elapsed, duration: dip.halfDuration, fromVolume: 0, toVolume: 1))
            } else if index > 0, !timeline.continuesFromPrevious(index) {
                fades.append(Fade(start: elapsed, duration: length, fromVolume: 0, toVolume: 1))
            }
            if let dip = dips[index + 1] {
                fades.append(Fade(start: end - dip.halfDuration, duration: dip.halfDuration, fromVolume: 1, toVolume: 0))
            } else if index < timeline.segments.count - 1, !timeline.continuesFromPrevious(index + 1) {
                fades.append(Fade(start: end - length, duration: length, fromVolume: 1, toVolume: 0))
            }
            elapsed = end
        }
        return fades
    }

    private static func audioMix(for track: AVMutableCompositionTrack, fades: [Fade]) -> AVAudioMix {
        let parameters = AVMutableAudioMixInputParameters(track: track)
        for fade in fades {
            parameters.setVolumeRamp(
                fromStartVolume: fade.fromVolume, toEndVolume: fade.toVolume,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: fade.start, preferredTimescale: 600),
                    duration: CMTime(seconds: fade.duration, preferredTimescale: 600)
                )
            )
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }
}
