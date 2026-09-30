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

    /// `processedAudio` replaces the take's sound when the Audio tool changed it. A montage's
    /// other recordings (`TakeEdit.sources`) are read from the edit's media; one that can't be read
    /// plays black and silent for its length.
    static func build(source: URL, edit: TakeEdit, processedAudio: URL?, options: Options) async throws -> EditedComposition {
        let take = try await Recording.load(AVURLAsset(url: source))
        let takeAudio: AVAssetTrack? = if let processedAudio {
            try await AVURLAsset(url: processedAudio).loadTracks(withMediaType: .audio).first
        } else {
            take.audio
        }
        var recordings: [UUID: Recording] = [:]
        for clip in edit.sources where edit.timeline.segments.contains(where: { $0.sourceID == clip.id }) {
            if let loaded = try? await Recording.load(AVURLAsset(url: EditMediaFiles.url(for: clip.fileName))) {
                recordings[clip.id] = loaded
            }
        }
        func recording(_ id: UUID?) -> Recording? { id.map { recordings[$0] } ?? take }

        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BuildError.noVideoTrack
        }
        let hasSound = takeAudio != nil || recordings.values.contains { $0.audio != nil }
        let audio = hasSound ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        var cursor = CMTime.zero
        for segment in edit.timeline.segments {
            let range = CMTimeRange(
                start: CMTime(seconds: segment.sourceStart, preferredTimescale: 600),
                duration: CMTime(seconds: segment.sourceLength, preferredTimescale: 600)
            )
            var soundInserted = false
            if let played = recording(segment.sourceID) {
                try video.insertTimeRange(range, of: played.video, at: cursor)
                let sound = segment.sourceID == nil ? takeAudio : played.audio
                if let audio, let sound {
                    soundInserted = (try? audio.insertTimeRange(range, of: sound, at: cursor)) != nil
                }
            } else {
                video.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: range.duration))
            }
            var length = range.duration
            if abs(segment.speed - 1) > 0.000_1 {
                // Faster or slower: the piece is stretched in place, picture and sound together.
                let inserted = CMTimeRange(start: cursor, duration: range.duration)
                length = CMTime(seconds: segment.duration, preferredTimescale: 600)
                if recording(segment.sourceID) != nil { video.scaleTimeRange(inserted, toDuration: length) }
                if soundInserted { audio?.scaleTimeRange(inserted, toDuration: length) }
            }
            cursor = cursor + length
        }

        let windows = TransitionWindow.windows(in: edit.timeline)
        var dissolves = windows.filter { $0.transition.showsBothSides }
        var blendTrack = dissolves.isEmpty ? nil : composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        if let track = blendTrack, (try? insertOtherSides(of: dissolves, from: recording, into: track)) == nil {
            // The recordings can't give the other sides: the cuts stay hard rather than failing.
            composition.removeTrack(track)
            blendTrack = nil
            dissolves = []
        }

        // The take's upright frame, its crop and the output size; other recordings are cropped the
        // same way and scaled to the take's crop.
        let crop = cropRect(for: take, edit: edit)
        let renderSize = outputSize(for: crop.size, shortSide: options.shortSide)
        func frame(_ id: UUID?) -> SourceFrame {
            guard let played = recording(id) else { return SourceFrame(transform: .identity, crop: crop, scale: 1) }
            let own = id == nil ? crop : cropRect(for: played, edit: edit)
            return SourceFrame(transform: played.transform, crop: own, scale: own.width > 0 ? crop.width / own.width : 1)
        }
        var overlays = TextOverlayRenderer.overlays(edit.editedTexts(in: edit.timeline), frame: crop.size)
        if options.burnsInCaptions, edit.showsCaptions {
            if let look = edit.captionLook {
                overlays += TextOverlayRenderer.captions(
                    edit.editedCaptions, look: look, position: edit.captionPosition, frame: crop.size, animation: edit.captionAnimation
                )
            } else {
                // Edits made before type presets keep their caption style.
                overlays += OverlayRenderer.captions(edit.editedCaptions, style: edit.captionStyle, position: edit.captionPosition, frame: crop.size)
            }
        }
        let (mediaTracks, mediaFrames) = await placeMedia(of: edit, frame: crop.size, in: composition, duration: cursor)
        let videoMedia = mediaFrames.filter(\.isVideo).map(\.span)
        let voices = await placeVoiceOvers(of: edit, in: composition)
        let fadeWindows = windows.filter { $0.transition == .fade }
        let outputScale = crop.width > 0 ? renderSize.width / crop.width : 1
        let timeline = edit.timeline
        let stretches = splitBySource(stretches(for: dissolves, media: videoMedia, duration: cursor), in: timeline)
        let instructions = stretches.map { stretch in
            let middle = CMTimeMultiplyByRatio(stretch.range.start + stretch.range.end, multiplier: 1, divisor: 2).seconds
            let index = timeline.segmentIndex(atEdited: middle)
            let played = timeline.segments[index].sourceID
            let zoom = timeline.segments[index].zoom.map {
                ZoomWindow(zoom: $0, start: timeline.editedStart(ofSegmentAt: index), duration: timeline.segments[index].duration)
            }
            // Before the cut the blend track holds the incoming piece; after it, the outgoing one.
            let blendSource = stretch.dissolve.map { middle < $0.cut ? $0.incomingSource : $0.outgoingSource }
            // The media tracks with a video in this stretch.
            let showing = mediaFrames.filter { frame in
                frame.isVideo && frame.span.overlaps(TimeSpan(start: stretch.range.start.seconds, end: stretch.range.end.seconds))
            }
            let mediaTrackIDs = stretch.showsMedia
                ? mediaTracks.map(\.trackID).filter { id in showing.contains { $0.trackID == id } }
                : []
            return CompositionInstruction(
                timeRange: stretch.range,
                trackID: video.trackID,
                blendTrackID: stretch.dissolve == nil ? nil : blendTrack?.trackID,
                mediaTrackIDs: mediaTrackIDs,
                frame: frame(played),
                blendFrame: stretch.dissolve == nil ? nil : frame(blendSource ?? nil),
                edit: edit,
                overlays: overlays,
                media: mediaFrames,
                outputScale: outputScale,
                dissolve: stretch.dissolve,
                zoom: zoom,
                fades: fadeWindows
            )
        }
        let configuration = AVVideoComposition.Configuration(
            customVideoCompositorClass: CueVideoCompositor.self,
            frameDuration: CMTime(value: 1, timescale: CMTimeScale(max(24, take.frameRate.rounded()))),
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

    /// A recording's video and sound, and how its frames stand.
    private struct Recording {
        let video: AVAssetTrack
        let audio: AVAssetTrack?
        let transform: CGAffineTransform
        let uprightSize: CGSize
        let frameRate: Float

        static func load(_ asset: AVURLAsset) async throws -> Recording {
            guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw BuildError.noVideoTrack }
            let (naturalSize, transform, frameRate) = try await video.load(.naturalSize, .preferredTransform, .nominalFrameRate)
            let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
            return Recording(
                video: video, audio: try await asset.loadTracks(withMediaType: .audio).first, transform: transform,
                uprightSize: CGSize(width: abs(upright.width), height: abs(upright.height)), frameRate: frameRate
            )
        }
    }

    /// The part of `recording`'s upright frame the edit keeps (Core Image coordinates, y from the
    /// bottom).
    private static func cropRect(for recording: Recording, edit: TakeEdit) -> CGRect {
        let size = recording.uprightSize
        let topLeft = CropMath.crop(in: size, aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset)
        return CGRect(x: topLeft.minX, y: size.height - topLeft.maxY, width: topLeft.width, height: topLeft.height)
    }

    /// Stretches cut again where the main track moves to another recording (and, in a dissolve
    /// between two recordings, at its cut) and where a section with a slow zoom starts or ends, so
    /// each stretch reads one recording on each track and has one zoom. An edit of the take alone
    /// without zooms stays as it was.
    static func splitBySource(
        _ stretches: [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)], in timeline: EditTimeline
    ) -> [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)] {
        let segments = timeline.segments
        var marks: [CMTime] = []
        for index in segments.indices.dropFirst()
        where segments[index].sourceID != segments[index - 1].sourceID || segments[index].zoom != nil || segments[index - 1].zoom != nil {
            marks.append(CMTime(seconds: timeline.editedStart(ofSegmentAt: index), preferredTimescale: 600))
        }
        guard !marks.isEmpty else { return stretches }
        var result: [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)] = []
        for stretch in stretches {
            let inside = marks.filter { CMTimeCompare($0, stretch.range.start) > 0 && CMTimeCompare($0, stretch.range.end) < 0 }
            var from = stretch.range.start
            for mark in inside + [stretch.range.end] where CMTimeCompare(mark, from) > 0 {
                result.append((CMTimeRange(start: from, end: mark), stretch.dissolve, stretch.showsMedia))
                from = mark
            }
        }
        return result
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
        of dissolves: [TransitionWindow], from recording: (UUID?) -> Recording?, into track: AVMutableCompositionTrack
    ) throws {
        var filled = CMTime.zero
        for window in dissolves {
            // Each side from its own recording.
            guard let incomingSource = recording(window.incomingSource)?.video,
                  let outgoingSource = recording(window.outgoingSource)?.video else { throw BuildError.noVideoTrack }
            let half = CMTime(seconds: window.halfDuration, preferredTimescale: 600)
            let start = CMTimeMaximum(CMTime(seconds: window.start, preferredTimescale: 600), filled)
            if CMTimeCompare(start, filled) > 0 { track.insertEmptyTimeRange(CMTimeRange(start: filled, end: start)) }
            // Each side plays at its own piece's speed.
            let incomingLength = CMTime(seconds: window.halfDuration * window.incomingSpeed, preferredTimescale: 600)
            let incoming = CMTime(seconds: window.incomingStart - window.halfDuration * window.incomingSpeed, preferredTimescale: 600)
            try track.insertTimeRange(CMTimeRange(start: incoming, duration: incomingLength), of: incomingSource, at: start)
            if CMTimeCompare(incomingLength, half) != 0 {
                track.scaleTimeRange(CMTimeRange(start: start, duration: incomingLength), toDuration: half)
            }
            let outgoingLength = CMTime(seconds: window.halfDuration * window.outgoingSpeed, preferredTimescale: 600)
            let outgoing = CMTime(seconds: window.outgoingEnd, preferredTimescale: 600)
            try track.insertTimeRange(CMTimeRange(start: outgoing, duration: outgoingLength), of: outgoingSource, at: start + half)
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

    /// Photos and videos over the take, placed on a frame of `size`, in their stacking order.
    /// Videos go on more video tracks (a second one only where two overlap, up to
    /// `MediaOverlay.simultaneousLimit`), each from its own start for as long as it shows; one that
    /// can't be read, or would need one track too many, is left out rather than failing the edit.
    private static func placeMedia(
        of edit: TakeEdit, frame size: CGSize, in composition: AVMutableComposition, duration: CMTime
    ) async -> (tracks: [AVMutableCompositionTrack], frames: [MediaFrame]) {
        let placed = edit.editedMedia(in: edit.timeline)
        guard !placed.isEmpty else { return ([], []) }
        var frames: [MediaFrame] = []
        var tracks: [(track: AVMutableCompositionTrack, filled: CMTime)] = []
        for entry in placed {
            let url = EditMediaFiles.url(for: entry.media.fileName)
            let topLeft = MediaPlacement.rect(for: entry.media, in: size)
            // Core Image measures y from the bottom.
            let rect = CGRect(x: topLeft.minX, y: size.height - topLeft.maxY, width: topLeft.width, height: topLeft.height)
            switch entry.media.kind {
            case .photo:
                guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { continue }
                var frame = MediaFrame(span: entry.span, rect: rect, image: image, transform: .identity, layer: entry.media.stackOrder)
                if let keyframes = entry.media.keyframes, !keyframes.isEmpty {
                    frame.motion = OverlayMotion(keyframes)
                    frame.frameSize = size
                }
                frames.append(frame)
            case .video:
                let asset = AVURLAsset(url: url)
                guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                      let transform = try? await source.load(.preferredTransform) else { continue }
                let start = CMTime(seconds: entry.span.start, preferredTimescale: 600)
                let end = CMTimeMinimum(CMTime(seconds: entry.span.end, preferredTimescale: 600), duration)
                guard CMTimeCompare(end, start) > 0 else { continue }
                // The first track free by then, or a new one.
                var slot = tracks.firstIndex { CMTimeCompare($0.filled, start) <= 0 }
                if slot == nil, tracks.count < MediaOverlay.simultaneousLimit,
                   let added = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    tracks.append((added, .zero))
                    slot = tracks.count - 1
                }
                guard let slot else { continue }
                let track = tracks[slot].track
                if CMTimeCompare(start, tracks[slot].filled) > 0 {
                    track.insertEmptyTimeRange(CMTimeRange(start: tracks[slot].filled, end: start))
                }
                do {
                    try track.insertTimeRange(CMTimeRange(start: .zero, end: end - start), of: source, at: start)
                } catch {
                    continue
                }
                tracks[slot].filled = end
                var frame = MediaFrame(
                    span: TimeSpan(start: start.seconds, end: end.seconds), rect: rect, image: nil, transform: transform,
                    trackID: track.trackID, layer: entry.media.stackOrder
                )
                if let keyframes = entry.media.keyframes, !keyframes.isEmpty {
                    frame.motion = OverlayMotion(keyframes)
                    frame.frameSize = size
                }
                frames.append(frame)
            }
        }
        let used = tracks.map(\.track).filter { track in frames.contains { $0.trackID == track.trackID } }
        for (track, _) in tracks where !used.contains(where: { $0.trackID == track.trackID }) { composition.removeTrack(track) }
        return (used, frames)
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
