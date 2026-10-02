//
//  EditedComposition.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// A take with its Quick edit applied, ready to play or export: the timeline's pieces joined in
/// order at their speed, the processed sound (dipped for a moment at each cut so it never clicks)
/// with the voice-overs, the music (lower while someone speaks, when it ducks) and the sound of
/// videos laid over the take mixed in, and a video composition that crops, adjusts and overlays
/// every frame: B-roll, texts and captions.
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
///
/// Music belongs to the edit, not to what is said: it's placed on the edit's own seconds, which in
/// the preview start `Options.window.start` into the grown timeline.
nonisolated struct EditedComposition: @unchecked Sendable {
    /// How long the sound fades out and back in around a cut that removed something.
    static let cutFade: TimeInterval = 0.012

    let asset: AVMutableComposition
    let videoComposition: AVVideoComposition
    /// Nil when the take has no sound.
    let audioMix: AVAudioMix?

    struct Options: Sendable {
        var burnsInCaptions: Bool
        /// Height of the output's short side in pixels (720, 1080 or 2160); nil keeps the recording's.
        var shortSide: CGFloat?
        /// Frames per second of the output; nil keeps the recording's.
        var frameRate: Double?
        /// Where the edit itself is in `edit.timeline`: the preview plays the timeline grown to the
        /// whole recording and holds playback here. Nil when the timeline is the edit.
        var window: TimeSpan?
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

    /// `processedAudio` replaces the take's sound when the Voice tool changed it. A montage's
    /// other recordings (`TakeEdit.sources`) are read from the edit's media; one that can't be read
    /// plays black and silent for its length. `speech` is where someone speaks in the recordings,
    /// for music that ducks.
    static func build(
        source: URL, edit: TakeEdit, processedAudio: URL?, speech: VoiceActivity = .none, options: Options
    ) async throws -> EditedComposition {
        let take = try await Recording.load(AVURLAsset(url: source))
        // A track can't be read once its asset is gone, so the processed sound's asset is kept
        // until the composition is built (like each `Recording`'s).
        let processedAsset = processedAudio.map { AVURLAsset(url: $0) }
        defer { withExtendedLifetime(processedAsset) {} }
        let takeAudio: AVAssetTrack? = if let processedAsset {
            try await processedAsset.loadTracks(withMediaType: .audio).first
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
        // Clips sped up or slowed down without "Keep voice pitch" play on their own sound track,
        // whose pitch follows the speed.
        let playsVarispeed: (EditSegment) -> Bool = { !$0.keepsPitch && abs($0.speed - 1) > 0.000_1 }
        let varispeed = hasSound && edit.timeline.segments.contains(where: playsVarispeed)
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil
        let cursor = try insertPieces(
            of: edit.timeline, recording: recording, takeAudio: takeAudio, video: video,
            soundTrack: { playsVarispeed($0) ? varispeed : audio }
        )
        var takeTracks: [(track: AVMutableCompositionTrack, levels: [Fade], pitch: AVAudioTimePitchAlgorithm?)] = []
        if let audio {
            takeTracks.append((audio, levels(for: edit.timeline) { !playsVarispeed($0) }, nil))
        }
        if let varispeed {
            takeTracks.append((varispeed, levels(for: edit.timeline, plays: playsVarispeed), .varispeed))
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
        // Each recording's background, prepared once; masks of this build are kept apart from others'.
        let build = UUID().uuidString
        var backgrounds: [UUID?: BackgroundRender] = [:]
        for id in [nil] + edit.playedSources.map(\.id) as [UUID?] {
            guard let effect = edit.background(for: id) else { continue }
            backgrounds[id] = BackgroundRender.prepare(effect, cacheKey: build + (id?.uuidString ?? "take"))
        }
        let ownBackgrounds = clipBackgrounds(of: edit.timeline, build: build)
        func frame(_ id: UUID?) -> SourceFrame {
            guard let played = recording(id) else { return SourceFrame(transform: .identity, crop: crop, scale: 1) }
            let own = id == nil ? crop : cropRect(for: played, edit: edit)
            return SourceFrame(
                transform: played.transform, crop: own, scale: own.width > 0 ? crop.width / own.width : 1,
                background: backgrounds[id] ?? nil
            )
        }
        func frame(of segment: EditSegment) -> SourceFrame {
            var result = frame(segment.sourceID)
            if let own = ownBackgrounds[segment.id] { result.background = own }
            return result
        }
        var overlays = TextOverlayRenderer.overlays(edit.editedTexts(in: edit.timeline), frame: crop.size)
        if options.burnsInCaptions, edit.showsCaptions {
            overlays += captionOverlays(for: edit, frame: crop.size)
        }
        let (mediaTracks, mediaFrames, mediaSounds) = await placeMedia(of: edit, frame: crop.size, in: composition, duration: cursor)
        let videoMedia = mediaFrames.filter(\.isVideo).map(\.span)
        let voices = await placeVoiceOvers(of: edit, in: composition)
        let window = options.window ?? TimeSpan(start: 0, end: cursor.seconds)
        let spoken = speech.editedSpans(in: edit.timeline) + edit.voiceOvers.compactMap { $0.editedSpan(in: edit.timeline) }
        let music = await placeMusic(of: edit, window: window, speech: spoken, in: composition)
        let fadeWindows = windows.filter { $0.transition == .fade }
        let outputScale = crop.width > 0 ? renderSize.width / crop.width : 1
        let timeline = edit.timeline
        let stretches = splitBySource(stretches(for: dissolves, media: videoMedia, duration: cursor), in: timeline)
        let instructions = stretches.map { stretch in
            let middle = CMTimeMultiplyByRatio(stretch.range.start + stretch.range.end, multiplier: 1, divisor: 2).seconds
            let index = timeline.segmentIndex(atEdited: middle)
            let playedSegment = timeline.segments[index]
            let zoom = timeline.segments[index].zoom.map {
                ZoomWindow(
                    zoom: $0, start: timeline.editedStart(ofSegmentAt: index), duration: timeline.segments[index].duration,
                    amount: timeline.segments[index].zoomAmount
                )
            }
            // Before the cut the blend track holds the incoming piece; after it, the outgoing one.
            let blendSegment = stretch.dissolve.map { timeline.segments[middle < $0.cut ? $0.join : $0.join - 1] }
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
                frame: frame(of: playedSegment),
                blendFrame: blendSegment.map { frame(of: $0) },
                edit: edit,
                look: edit.lookSettings(for: playedSegment),
                blendLook: blendSegment.map { edit.lookSettings(for: $0) },
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
            frameDuration: CMTime(value: 1, timescale: CMTimeScale(max(24, (options.frameRate ?? Double(take.frameRate)).rounded()))),
            instructions: instructions,
            renderScale: 1,
            renderSize: renderSize
        )
        return EditedComposition(
            asset: composition,
            videoComposition: AVVideoComposition(configuration: configuration),
            audioMix: audioMix(for: takeTracks, voices: voices + mediaSounds, music: music)
        )
    }

    /// The backgrounds clips set for themselves, prepared once, by clip. A clip with one is drawn with
    /// it instead of its recording's; an Original one is a choice too (no effect: `nil`).
    private static func clipBackgrounds(of timeline: EditTimeline, build: String) -> [UUID: BackgroundRender?] {
        var result: [UUID: BackgroundRender?] = [:]
        for segment in timeline.segments {
            guard let effect = segment.look?.background else { continue }
            result.updateValue(BackgroundRender.prepare(effect, cacheKey: build + "clip-" + segment.id.uuidString), forKey: segment.id)
        }
        return result
    }

    /// Lays the timeline's pieces one after the other: picture on `video`, sound on the track
    /// `soundTrack` picks for each, each stretched to its speed. Returns where the edit ends.
    private static func insertPieces(
        of timeline: EditTimeline, recording: (UUID?) -> Recording?, takeAudio: AVAssetTrack?, video: AVMutableCompositionTrack,
        soundTrack track: (EditSegment) -> AVMutableCompositionTrack?
    ) throws -> CMTime {
        var cursor = CMTime.zero
        for segment in timeline.segments {
            let range = CMTimeRange(
                start: CMTime(seconds: segment.sourceStart, preferredTimescale: 600),
                duration: CMTime(seconds: segment.sourceLength, preferredTimescale: 600)
            )
            let soundTrack = track(segment)
            var soundInserted = false
            if let played = recording(segment.sourceID) {
                try video.insertTimeRange(range, of: played.video, at: cursor)
                let sound = segment.sourceID == nil ? takeAudio : played.audio
                if let soundTrack, let sound {
                    let filled = soundTrack.timeRange.end
                    if CMTimeCompare(cursor, filled) > 0 { soundTrack.insertEmptyTimeRange(CMTimeRange(start: filled, end: cursor)) }
                    soundInserted = (try? soundTrack.insertTimeRange(range, of: sound, at: cursor)) != nil
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
                if soundInserted { soundTrack?.scaleTimeRange(inserted, toDuration: length) }
            }
            cursor = CMTimeAdd(cursor, length)
        }
        return cursor
    }

    /// A recording's video and sound, and how its frames stand. Keeps its asset: its tracks can't
    /// be inserted once the asset is gone.
    private struct Recording {
        let asset: AVURLAsset
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
                asset: asset, video: video, audio: try await asset.loadTracks(withMediaType: .audio).first, transform: transform,
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
    /// each stretch reads one recording on each track and has one zoom, and where the next clip has
    /// another look or background (`EditSegment.look`), so each stretch is drawn one way. An edit of
    /// the take alone without zooms or clip looks stays as it was.
    static func splitBySource(
        _ stretches: [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)], in timeline: EditTimeline
    ) -> [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)] {
        let segments = timeline.segments
        var marks: [CMTime] = []
        for index in segments.indices.dropFirst()
        where segments[index].sourceID != segments[index - 1].sourceID || segments[index].zoom != nil || segments[index - 1].zoom != nil
            || segments[index].look != segments[index - 1].look {
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
    ) async -> (tracks: [AVMutableCompositionTrack], frames: [MediaFrame], sounds: [(track: AVMutableCompositionTrack, volume: Float)]) {
        let placed = edit.editedMedia(in: edit.timeline)
        guard !placed.isEmpty else { return ([], [], []) }
        var frames: [MediaFrame] = []
        var sounds: [(track: AVMutableCompositionTrack, volume: Float)] = []
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
                if let volume = entry.media.audioVolume, volume > 0,
                   let sound = await placeSound(of: asset, from: start, to: end, in: composition) {
                    sounds.append((sound, Float(min(max(volume, 0), 1))))
                }
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
        return (used, frames, sounds)
    }

    /// A video's own sound on a sound track of its own, from its start for as long as it shows.
    private static func placeSound(
        of asset: AVURLAsset, from start: CMTime, to end: CMTime, in composition: AVMutableComposition
    ) async -> AVMutableCompositionTrack? {
        guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
              let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return nil }
        let available = (try? await source.load(.timeRange).duration) ?? (end - start)
        do {
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(end - start, available)), of: source, at: start)
        } catch {
            composition.removeTrack(track)
            return nil
        }
        return track
    }

    /// Each music clip that isn't muted on its own sound track, on the edit's seconds within
    /// `window`, with how loud it is over time.
    private static func placeMusic(
        of edit: TakeEdit, window: TimeSpan, speech: [TimeSpan], in composition: AVMutableComposition
    ) async -> [(track: AVMutableCompositionTrack, points: [MusicEnvelope.Point])] {
        var placed: [(track: AVMutableCompositionTrack, points: [MusicEnvelope.Point])] = []
        for clip in edit.music where !clip.isMuted {
            let start = window.start + clip.start
            let end = min(window.end, start + clip.length)
            guard end - start >= 0.05 else { continue }
            let asset = AVURLAsset(url: EditMediaFiles.url(for: clip.fileName))
            guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }
            let range = CMTimeRange(
                start: CMTime(seconds: clip.offset, preferredTimescale: 600),
                duration: CMTime(seconds: end - start, preferredTimescale: 600)
            )
            do {
                try track.insertTimeRange(range, of: source, at: CMTime(seconds: start, preferredTimescale: 600))
            } catch {
                composition.removeTrack(track)
                continue
            }
            let points = MusicEnvelope.points(
                span: TimeSpan(start: start, end: end), volume: clip.volume, fadeIn: clip.fadeIn, fadeOut: clip.fadeOut,
                speech: clip.ducksUnderVoice ? speech : nil
            )
            placed.append((track, points))
        }
        return placed
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
            voices.append((track, Float(min(max(clip.volume, VoiceOverClip.volumeRange.lowerBound), VoiceOverClip.volumeRange.upperBound))))
        }
        return voices
    }

    // MARK: - Sound at the cuts

    /// A short dip in the sound at each seam where something was removed, so joining two
    /// waveforms mid-cycle never clicks. Cuts that removed nothing play straight through. A fade
    /// takes the sound down to silence and back with the picture instead. (The ramps of `levels`,
    /// with every clip at full volume.)
    static func fades(for timeline: EditTimeline) -> [Fade] {
        levels(for: timeline) { _ in true }.filter { $0.duration > 0 }
    }

    /// The take's sound level along the edit on one sound track: each clip at its volume (silent
    /// while muted, or where it plays on another track: `plays` says which clips this track
    /// carries), the dips at the cuts scaled to it, and a quick ramp where two clips that run on
    /// from each other have different volumes. A `Fade` without duration sets the level at its
    /// start.
    static func levels(for timeline: EditTimeline, plays: (EditSegment) -> Bool) -> [Fade] {
        var dips: [Int: TransitionWindow] = [:]
        for window in TransitionWindow.windows(in: timeline) where window.transition == .fade {
            dips[window.join] = window
        }
        let segments = timeline.segments
        func level(_ index: Int) -> Float {
            let segment = segments[index]
            guard plays(segment), !segment.isMuted else { return 0 }
            return Float(min(max(segment.volume, EditSegment.volumeRange.lowerBound), EditSegment.volumeRange.upperBound))
        }
        let uniform = segments.indices.allSatisfy { level($0) == 1 }
        var fades: [Fade] = []
        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let end = elapsed + segment.duration
            let length = min(cutFade, segment.duration / 2)
            let volume = level(index)
            if let dip = dips[index] {
                fades.append(Fade(start: elapsed, duration: dip.halfDuration, fromVolume: 0, toVolume: volume))
            } else if index > 0, !timeline.isSeamless(index) {
                fades.append(Fade(start: elapsed, duration: length, fromVolume: 0, toVolume: volume))
            } else if !uniform {
                let previous = index > 0 ? level(index - 1) : volume
                if index > 0, previous != volume {
                    fades.append(Fade(start: elapsed, duration: length, fromVolume: previous, toVolume: volume))
                } else {
                    fades.append(Fade(start: elapsed, duration: 0, fromVolume: volume, toVolume: volume))
                }
            }
            if let dip = dips[index + 1] {
                fades.append(Fade(start: end - dip.halfDuration, duration: dip.halfDuration, fromVolume: volume, toVolume: 0))
            } else if index < segments.count - 1, !timeline.isSeamless(index + 1) {
                fades.append(Fade(start: end - length, duration: length, fromVolume: volume, toVolume: 0))
            }
            elapsed = end
        }
        return fades
    }

    /// The take's sound with its dips, each voice-over and video sound at its volume, and the music
    /// along its envelope; nil with no sound at all.
    private static func audioMix(
        for takeTracks: [(track: AVMutableCompositionTrack, levels: [Fade], pitch: AVAudioTimePitchAlgorithm?)],
        voices: [(track: AVMutableCompositionTrack, volume: Float)],
        music: [(track: AVMutableCompositionTrack, points: [MusicEnvelope.Point])]
    ) -> AVAudioMix? {
        var inputs: [AVMutableAudioMixInputParameters] = []
        for take in takeTracks {
            let parameters = AVMutableAudioMixInputParameters(track: take.track)
            if let pitch = take.pitch { parameters.audioTimePitchAlgorithm = pitch }
            for fade in take.levels {
                let start = CMTime(seconds: fade.start, preferredTimescale: 600)
                if fade.duration <= 0 {
                    parameters.setVolume(fade.toVolume, at: start)
                } else {
                    parameters.setVolumeRamp(
                        fromStartVolume: fade.fromVolume, toEndVolume: fade.toVolume,
                        timeRange: CMTimeRange(start: start, duration: CMTime(seconds: fade.duration, preferredTimescale: 600))
                    )
                }
            }
            inputs.append(parameters)
        }
        for voice in voices {
            let parameters = AVMutableAudioMixInputParameters(track: voice.track)
            parameters.setVolume(voice.volume, at: .zero)
            inputs.append(parameters)
        }
        for clip in music {
            let parameters = AVMutableAudioMixInputParameters(track: clip.track)
            if let first = clip.points.first { parameters.setVolume(Float(first.volume), at: .zero) }
            for (from, to) in zip(clip.points, clip.points.dropFirst()) where to.time - from.time > 0.000_1 {
                parameters.setVolumeRamp(
                    fromStartVolume: Float(from.volume), toEndVolume: Float(to.volume),
                    timeRange: CMTimeRange(
                        start: CMTime(seconds: from.time, preferredTimescale: 600),
                        end: CMTime(seconds: to.time, preferredTimescale: 600)
                    )
                )
            }
            inputs.append(parameters)
        }
        guard !inputs.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = inputs
        return mix
    }
}
