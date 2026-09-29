//
//  EditedComposition.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// A take with its Quick edit applied, ready to play or export: the timeline's pieces joined in
/// order at their speed, the processed sound (dipped for a moment at each cut so it never clicks)
/// with the voice-overs mixed in, and a video composition that crops, adjusts and overlays every
/// frame: B-roll, texts and captions.
///
/// Everything added on top is placed with `edit.timeline`, which is the edit itself for an export
/// and the edit grown to the whole recording (`EditTimeline.reachable`) for the preview: texts,
/// media and voice-overs are pinned to the recording, so both land on the same moments.
///
/// Transitions (`TransitionWindow`) never change the length. A fade darkens the frames and the
/// sound around its cut. A dissolve reads a second video track that holds, around each dissolving
/// cut, the other side of it from the recording (the incoming piece before the cut, the outgoing
/// one after it), and the compositor blends the two (or slides one over the other).
///
/// Photos and videos laid over the take show one at a time: videos share one more video track,
/// read only while one shows.
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
        for segment in edit.timeline.segments {
            let range = CMTimeRange(
                start: CMTime(seconds: segment.sourceStart, preferredTimescale: 600),
                duration: CMTime(seconds: segment.sourceLength, preferredTimescale: 600)
            )
            try video.insertTimeRange(range, of: videoTrack, at: cursor)
            var hasSound = false
            if let audio, let audioTrack {
                hasSound = (try? audio.insertTimeRange(range, of: audioTrack, at: cursor)) != nil
            }
            var length = range.duration
            if abs(segment.speed - 1) > 0.000_1 {
                // Faster or slower: the piece is stretched in place, picture and sound together.
                let inserted = CMTimeRange(start: cursor, duration: range.duration)
                length = CMTime(seconds: segment.duration, preferredTimescale: 600)
                video.scaleTimeRange(inserted, toDuration: length)
                if hasSound { audio?.scaleTimeRange(inserted, toDuration: length) }
            }
            cursor = cursor + length
        }

        let windows = TransitionWindow.windows(in: edit.timeline)
        var dissolves = windows.filter { $0.transition.showsBothSides }
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

        var overlays = TextOverlayRenderer.overlays(edit.editedTexts(in: edit.timeline), frame: crop.size)
        if options.burnsInCaptions, edit.showsCaptions {
            overlays += OverlayRenderer.captions(edit.editedCaptions, style: edit.captionStyle, position: edit.captionPosition, frame: crop.size)
        }
        let (mediaTrack, mediaFrames) = await placeMedia(of: edit, frame: crop.size, in: composition, duration: cursor)
        let videoMedia = mediaFrames.filter(\.isVideo).map(\.span)
        let voices = await placeVoiceOvers(of: edit, in: composition)

        let fadeWindows = windows.filter { $0.transition == .fade }
        let outputScale = crop.width > 0 ? renderSize.width / crop.width : 1
        let instructions = stretches(for: dissolves, media: videoMedia, duration: cursor).map { stretch in
            CompositionInstruction(
                timeRange: stretch.range,
                trackID: video.trackID,
                blendTrackID: stretch.dissolve == nil ? nil : blendTrack?.trackID,
                mediaTrackID: stretch.showsMedia ? mediaTrack?.trackID : nil,
                transform: transform,
                crop: crop,
                edit: edit,
                overlays: overlays,
                media: mediaFrames,
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
            audioMix: audioMix(for: audio, fades: fades(for: edit.timeline), voices: voices)
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
            // Each side plays at its own piece's speed.
            let incomingLength = CMTime(seconds: window.halfDuration * window.incomingSpeed, preferredTimescale: 600)
            let incoming = CMTime(seconds: window.incomingStart - window.halfDuration * window.incomingSpeed, preferredTimescale: 600)
            try track.insertTimeRange(CMTimeRange(start: incoming, duration: incomingLength), of: source, at: start)
            if CMTimeCompare(incomingLength, half) != 0 {
                track.scaleTimeRange(CMTimeRange(start: start, duration: incomingLength), toDuration: half)
            }
            let outgoingLength = CMTime(seconds: window.halfDuration * window.outgoingSpeed, preferredTimescale: 600)
            let outgoing = CMTime(seconds: window.outgoingEnd, preferredTimescale: 600)
            try track.insertTimeRange(CMTimeRange(start: outgoing, duration: outgoingLength), of: source, at: start + half)
            if CMTimeCompare(outgoingLength, half) != 0 {
                track.scaleTimeRange(CMTimeRange(start: start + half, duration: outgoingLength), toDuration: half)
            }
            filled = start + half + half
        }
    }

    /// The edit cut into stretches the compositor renders the same way: each dissolve on its own
    /// (reading both tracks), the rest from the main track alone. They follow on without gaps
    /// from the start to `duration`.
    static func instructionRanges(
        for dissolves: [TransitionWindow], duration: CMTime
    ) -> [(range: CMTimeRange, dissolve: TransitionWindow?)] {
        stretches(for: dissolves, media: [], duration: duration).map { ($0.range, $0.dissolve) }
    }

    /// Like `instructionRanges`, also cut where a video over the take (`media`, edited seconds)
    /// starts and ends, so the media track is only read while one shows.
    static func stretches(
        for dissolves: [TransitionWindow], media: [TimeSpan], duration: CMTime
    ) -> [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)] {
        var windows: [(range: CMTimeRange, dissolve: TransitionWindow?)] = []
        var from = CMTime.zero
        for window in dissolves {
            let start = CMTimeMaximum(CMTime(seconds: window.start, preferredTimescale: 600), from)
            let end = CMTimeMinimum(CMTime(seconds: window.end, preferredTimescale: 600), duration)
            guard CMTimeCompare(end, start) > 0 else { continue }
            if CMTimeCompare(start, from) > 0 { windows.append((CMTimeRange(start: from, end: start), nil)) }
            windows.append((CMTimeRange(start: start, end: end), window))
            from = end
        }
        if CMTimeCompare(duration, from) > 0 || windows.isEmpty {
            windows.append((CMTimeRange(start: from, end: CMTimeMaximum(from, duration)), nil))
        }
        guard !media.isEmpty else { return windows.map { ($0.range, $0.dissolve, false) } }
        let mediaRanges = media.map {
            CMTimeRange(
                start: CMTime(seconds: $0.start, preferredTimescale: 600),
                end: CMTime(seconds: $0.end, preferredTimescale: 600)
            )
        }
        let marks = mediaRanges.flatMap { [$0.start, $0.end] }
        var result: [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)] = []
        for window in windows {
            let inside = marks
                .filter { CMTimeCompare($0, window.range.start) > 0 && CMTimeCompare($0, window.range.end) < 0 }
                .sorted { CMTimeCompare($0, $1) < 0 }
            var start = window.range.start
            for end in inside + [window.range.end] where CMTimeCompare(end, start) > 0 {
                let range = CMTimeRange(start: start, end: end)
                let middle = CMTimeMultiplyByRatio(range.start + range.end, multiplier: 1, divisor: 2)
                let showsMedia = mediaRanges.contains { $0.containsTime(middle) }
                result.append((range, window.dissolve, showsMedia))
                start = end
            }
        }
        return result
    }

    // MARK: - Media and voice-overs

    /// Photos and videos over the take, placed on a frame of `size`. Videos go on one more video
    /// track, each from its own start for as long as it shows; one that can't be read is left out
    /// rather than failing the edit.
    private static func placeMedia(
        of edit: TakeEdit, frame size: CGSize, in composition: AVMutableComposition, duration: CMTime
    ) async -> (track: AVMutableCompositionTrack?, frames: [MediaFrame]) {
        let placed = edit.editedMedia(in: edit.timeline)
        guard !placed.isEmpty else { return (nil, []) }
        var frames: [MediaFrame] = []
        var track: AVMutableCompositionTrack?
        var filled = CMTime.zero
        for entry in placed {
            let url = EditMediaFiles.url(for: entry.media.fileName)
            let topLeft = MediaPlacement.rect(for: entry.media, in: size)
            // Core Image measures y from the bottom.
            let rect = CGRect(x: topLeft.minX, y: size.height - topLeft.maxY, width: topLeft.width, height: topLeft.height)
            switch entry.media.kind {
            case .photo:
                guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { continue }
                frames.append(MediaFrame(span: entry.span, rect: rect, image: image, transform: .identity))
            case .video:
                let asset = AVURLAsset(url: url)
                guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                      let transform = try? await source.load(.preferredTransform) else { continue }
                if track == nil {
                    track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                }
                guard let track else { continue }
                let start = CMTimeMaximum(CMTime(seconds: entry.span.start, preferredTimescale: 600), filled)
                let end = CMTimeMinimum(CMTime(seconds: entry.span.end, preferredTimescale: 600), duration)
                guard CMTimeCompare(end, start) > 0 else { continue }
                if CMTimeCompare(start, filled) > 0 { track.insertEmptyTimeRange(CMTimeRange(start: filled, end: start)) }
                do {
                    try track.insertTimeRange(CMTimeRange(start: .zero, end: end - start), of: source, at: start)
                } catch {
                    continue
                }
                filled = end
                frames.append(MediaFrame(span: TimeSpan(start: start.seconds, end: end.seconds), rect: rect, image: nil, transform: transform))
            }
        }
        if let track, !frames.contains(where: \.isVideo) {
            composition.removeTrack(track)
            return (nil, frames)
        }
        return (track, frames)
    }

    /// Each voice-over on its own sound track, from where it starts, cut at the end of the edit.
    private static func placeVoiceOvers(
        of edit: TakeEdit, in composition: AVMutableComposition
    ) async -> [(track: AVMutableCompositionTrack, volume: Float)] {
        var voices: [(track: AVMutableCompositionTrack, volume: Float)] = []
        for clip in edit.voiceOvers {
            guard let span = clip.editedSpan(in: edit.timeline) else { continue }
            let asset = AVURLAsset(url: EditMediaFiles.url(for: clip.fileName))
            guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }
            let range = CMTimeRange(start: .zero, duration: CMTime(seconds: span.duration, preferredTimescale: 600))
            do {
                try track.insertTimeRange(range, of: source, at: CMTime(seconds: span.start, preferredTimescale: 600))
            } catch {
                composition.removeTrack(track)
                continue
            }
            voices.append((track, Float(min(max(clip.volume, 0), 1))))
        }
        return voices
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
            } else if index > 0, !timeline.isSeamless(index) {
                fades.append(Fade(start: elapsed, duration: length, fromVolume: 0, toVolume: 1))
            }
            if let dip = dips[index + 1] {
                fades.append(Fade(start: end - dip.halfDuration, duration: dip.halfDuration, fromVolume: 1, toVolume: 0))
            } else if index < timeline.segments.count - 1, !timeline.isSeamless(index + 1) {
                fades.append(Fade(start: end - length, duration: length, fromVolume: 1, toVolume: 0))
            }
            elapsed = end
        }
        return fades
    }

    /// The take's sound with its dips, and each voice-over at its volume; nil with no sound at all.
    private static func audioMix(
        for track: AVMutableCompositionTrack?, fades: [Fade], voices: [(track: AVMutableCompositionTrack, volume: Float)]
    ) -> AVAudioMix? {
        var inputs: [AVMutableAudioMixInputParameters] = []
        if let track {
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
            inputs.append(parameters)
        }
        for voice in voices {
            let parameters = AVMutableAudioMixInputParameters(track: voice.track)
            parameters.setVolume(voice.volume, at: .zero)
            inputs.append(parameters)
        }
        guard !inputs.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = inputs
        return mix
    }
}
