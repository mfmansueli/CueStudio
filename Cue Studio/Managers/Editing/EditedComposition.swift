//
//  EditedComposition.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// A take with its Quick edit applied, ready to play or export: the timeline's pieces joined in
/// order at their speed, each recording's sound (Studio Voice's where it treated it, dipped for a moment at each cut so it never clicks)
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
/// Photos and videos laid over the take go on more video tracks, read only while one shows. A support of a split screen
/// takes its area and moves the main video to the other one, framed there from the recording itself (`FramePipeline`), so
/// Format's crop never limits what the area can show; where no support shows, the main video has the whole frame again.
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

    struct Options: Equatable, Sendable {
        var burnsInCaptions: Bool
        /// Height of the output's short side in pixels (720, 1080 or 2160); nil keeps the recording's.
        var shortSide: CGFloat?
        /// Frames per second of the output; nil keeps the recording's.
        var frameRate: Double?
        /// The editor's preview: the first and last clips grown to the whole recording (`EditTimeline.reachable`), so a handle
        /// scrubs real frames without a rebuild; the player holds playback where the edit itself is.
        var reachesWholeRecording = false
        /// Makes the motion analyses Follow face and stabilization need when they're missing (an export); the preview draws
        /// with the ones ready.
        var analyzesMissingMotion = true
        /// Renders curved clips' sound along their curves (`CurveSoundRenderer`); off, it's stretched in steps like the picture,
        /// which is instant: the preview while a finger shapes a curve or drags a handle.
        var rendersCurveSound = true
        /// The editor's preview shows the picked text, photo or video whole while paused (`PreviewMotionHold`); never an export.
        var showsPickedWhole = false
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
        /// The iPhone got too hot to finish the motion analysis an export needs (`motionAnalyses`).
        case tooWarm
    }

    /// The composition of `plan` (`RenderPlan`), which is all it reads of the edit. `sound` replaces the sound of the
    /// recordings Studio Voice treated (`RecordingSounds`). A montage's other recordings (`TakeEdit.sources`) are read from the
    /// edit's media; one that can't be read plays black and silent for its length. `speech` is where someone speaks in the
    /// recordings, for music that ducks. Built off the main thread (`@concurrent`): the preview rebuilds while a finger drags a
    /// handle, a slider or the frame, and the screen keeps following the finger meanwhile.
    @concurrent
    static func build(
        source: URL, plan: RenderPlan, sound: RecordingSounds = .none, speech: VoiceActivity = .none
    ) async throws -> EditedComposition {
        // The edit as drawn; the preview plays the edit as made in it from `leadIn` on.
        let edit = plan.drawn
        let options = plan.options
        let leadIn = plan.leadIn
        let leadPieces = plan.leadPieces
        let take = try await Recording.load(AVURLAsset(url: source))
        // A track can't be read once its asset is gone, so the treated sounds' assets are kept
        // until the composition is built (like each `Recording`'s).
        var treatedAssets: [UUID?: AVURLAsset] = [:]
        for id in [nil] + Array(sound.sources.keys) as [UUID?] {
            if let file = sound.file(for: id) { treatedAssets[id] = AVURLAsset(url: file) }
        }
        defer { withExtendedLifetime(treatedAssets) {} }
        var treatedAudio: [UUID?: AVAssetTrack] = [:]
        for (id, asset) in treatedAssets {
            if let track = try await asset.loadTracks(withMediaType: .audio).first { treatedAudio[id] = track }
        }
        let takeAudio = treatedAudio[nil] ?? take.audio
        var recordings: [UUID: Recording] = [:]
        for clip in edit.sources where edit.timeline.segments.contains(where: { $0.sourceID == clip.id }) {
            if let loaded = try? await Recording.load(AVURLAsset(url: EditMediaFiles.url(for: clip.fileName))) {
                recordings[clip.id] = loaded
            }
        }
        func recording(_ id: UUID?) -> Recording? { id.map { recordings[$0] } ?? take }
        func recordingSound(of id: UUID?) -> AVAssetTrack? { id == nil ? takeAudio : (treatedAudio[id] ?? recording(id)?.audio) }

        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BuildError.noVideoTrack
        }
        let hasSound = takeAudio != nil || recordings.keys.contains { recordingSound(of: $0) != nil }
        let audio = hasSound ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        // Clips sped up or slowed down without "Keep voice pitch" play on their own sound track,
        // whose pitch follows the speed.
        let playsVarispeed: (EditSegment) -> Bool = { !$0.keepsPitch && $0.changesSpeed }
        let varispeed = hasSound && edit.timeline.segments.contains(where: playsVarispeed)
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil
        // Clips with a voice effect play their stretch through it (`+VoiceEffects`); curved ones then along the curve.
        let (effectAssets, effectSounds) = try await effectSounds(for: edit.timeline.segments, sound: recordingSound(of:))
        defer { withExtendedLifetime(effectAssets) {} }
        // Curved clips get their sound rendered along the curve (see `CurveSoundRenderer`), unless it's wanted at once.
        let curved = options.rendersCurveSound ? edit.timeline.segments : []
        let (curveAssets, curveSounds) = try await curveSounds(for: curved, sound: recordingSound(of:), effects: effectSounds)
        defer { withExtendedLifetime(curveAssets) {} }
        let cursor = try insertPieces(
            of: edit.timeline, recording: recording, sound: recordingSound(of:), effectSounds: effectSounds, curveSounds: curveSounds,
            video: video, soundTrack: { playsVarispeed($0) ? varispeed : audio }
        )
        // The main video turned down while a support shows with the main's volume lowered.
        let quieter = mainSoundWindows(of: edit)
        var takeTracks: [(track: AVMutableCompositionTrack, levels: [Fade], pitch: AVAudioTimePitchAlgorithm?)] = []
        if let audio {
            takeTracks.append((audio, MainSoundLevels.scaled(levels(for: edit.timeline) { !playsVarispeed($0) }, by: quieter), nil))
        }
        if let varispeed {
            takeTracks.append((varispeed, MainSoundLevels.scaled(levels(for: edit.timeline, plays: playsVarispeed), by: quieter), .varispeed))
        }

        let windows = plan.transitions
        let zooms = plan.zooms
        let phraseZooms = plan.phraseZooms
        let animations = plan.animations
        var dissolves = windows.filter { $0.transition.showsBothSides }
        var blendTrack = dissolves.isEmpty ? nil : composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        if let track = blendTrack, (try? insertOtherSides(of: dissolves, from: recording, into: track)) == nil {
            // The recordings can't give the other sides: the cuts stay hard rather than failing.
            composition.removeTrack(track)
            blendTrack = nil
            dissolves = []
        }

        // How each recording lands on the take's frame (`EditFraming`, which frames the cover too): its crop, the scale that
        // brings another recording to the take's crop, backgrounds (masks of this build are kept apart from others'), Follow
        // face and Stabilize.
        let analyses = try await motionAnalyses(take: source, edit: edit, analyzesMissing: options.analyzesMissingMotion)
        var framing = EditFraming(
            edit: edit, take: source, takeShape: take.shape, shapes: recordings.mapValues(\.shape), analyses: analyses,
            cacheKey: UUID().uuidString
        )
        let crop = framing.crop
        let renderSize = outputSize(for: crop.size, shortSide: options.shortSide)
        var overlays = TextOverlayRenderer.overlays(shownTexts(of: edit, window: plan.window), frame: crop.size)
        if options.showsPickedWhole { for index in overlays.indices { overlays[index].readsPreviewHold = true } }
        if options.burnsInCaptions, edit.showsCaptions {
            overlays += captionOverlays(for: edit, frame: crop.size)
        }
        let (mediaTracks, placedMedia, mediaSounds) = await placeMedia(of: edit, frame: crop.size, in: composition, duration: cursor)
        var mediaFrames = placedMedia
        if options.showsPickedWhole { for index in mediaFrames.indices { mediaFrames[index].readsPreviewHold = true } }
        let videoMedia = mediaFrames.filter(\.isVideo).flatMap(\.shownSpans)
        let voices = try await placeVoiceOvers(of: edit, in: composition)
        let window = plan.window ?? TimeSpan(start: 0, end: cursor.seconds)
        let spoken = SpokenSpans(edit: edit, speech: speech, window: window)
        let music = await placeMusic(of: edit, window: window, speech: spoken, in: composition)
        let fadeWindows = windows.filter { $0.transition == .fade }
        let outputScale = crop.width > 0 ? renderSize.width / crop.width : 1
        let timeline = edit.timeline
        let stretches = splitBySource(stretches(for: dissolves, media: videoMedia, duration: cursor), in: timeline)
        let instructions = stretches.map { stretch in
            let middle = CMTimeMultiplyByRatio(stretch.range.start + stretch.range.end, multiplier: 1, divisor: 2).seconds
            let index = timeline.segmentIndex(atEdited: middle)
            let playedSegment = timeline.segments[index]
            // The piece of the edit as made this one plays (the grown timeline may put one before it).
            let shownIndex = index - leadPieces
            let zoom = zooms.indices.contains(shownIndex) ? zooms[shownIndex] : nil
            let animation = animations.indices.contains(shownIndex) ? animations[shownIndex] : nil
            // Before the cut the blend track holds the incoming piece; after it, the outgoing one.
            let blendIndex = stretch.dissolve.map { middle < $0.cut ? $0.join : $0.join - 1 }
            let blendSegment = blendIndex.map { timeline.segments[$0] }
            let blendAnimation = blendIndex.flatMap { index in
                animations.indices.contains(index - leadPieces) ? animations[index - leadPieces] : nil
            }
            // The media tracks with a video in this stretch.
            let stretchSpan = TimeSpan(start: stretch.range.start.seconds, end: stretch.range.end.seconds)
            let showing = mediaFrames.filter { frame in
                frame.isVideo && frame.shownSpans.contains { $0.overlaps(stretchSpan) }
            }
            let mediaTrackIDs = stretch.showsMedia
                ? mediaTracks.map(\.trackID).filter { id in showing.contains { $0.trackID == id } }
                : []
            let instruction = CompositionInstruction(
                timeRange: stretch.range,
                trackID: video.trackID,
                blendTrackID: stretch.dissolve == nil ? nil : blendTrack?.trackID,
                mediaTrackIDs: mediaTrackIDs,
                frame: framing.frame(of: playedSegment),
                blendFrame: blendSegment.map { framing.frame(of: $0) },
                recordingID: playedSegment.sourceID,
                blendRecordingID: blendSegment?.sourceID,
                mainFraming: edit.splitScreen.framing(for: playedSegment.sourceID),
                blendMainFraming: blendSegment.map { edit.splitScreen.framing(for: $0.sourceID) },
                edit: edit,
                look: edit.lookSettings(for: playedSegment),
                blendLook: blendSegment.map { edit.lookSettings(for: $0) },
                overlays: overlays,
                media: mediaFrames,
                outputScale: outputScale,
                dissolve: stretch.dissolve,
                zoom: zoom,
                animations: (animation, blendAnimation),
                fades: fadeWindows,
                timeOrigin: leadIn
            )
            instruction.phraseZooms = phraseZooms.filter { $0.span.overlaps(stretchSpan) || $0.span.contains(stretchSpan.start) }
            return instruction
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

    /// Lays the timeline's pieces one after the other: picture on `video`, sound on the track
    /// `soundTrack` picks for each (a voice effect's when the clip has one: its stretch alone, from its start), each stretched
    /// to its speed. Returns where the edit ends.
    private static func insertPieces(
        of timeline: EditTimeline, recording: (UUID?) -> Recording?, sound soundOf: (UUID?) -> AVAssetTrack?,
        effectSounds: [UUID: AVAssetTrack] = [:], curveSounds: [UUID: AVAssetTrack] = [:], video: AVMutableCompositionTrack,
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
                let sound = soundOf(segment.sourceID)
                if let soundTrack, let rendered = curveSounds[segment.id] {
                    // Already as long as the curve makes it: laid in as it is.
                    let filled = soundTrack.timeRange.end
                    if CMTimeCompare(cursor, filled) > 0 { soundTrack.insertEmptyTimeRange(CMTimeRange(start: filled, end: cursor)) }
                    let length = CMTime(seconds: segment.duration, preferredTimescale: 60_000)
                    try? soundTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: rendered, at: cursor)
                } else if let soundTrack, let effected = effectSounds[segment.id] {
                    let filled = soundTrack.timeRange.end
                    if CMTimeCompare(cursor, filled) > 0 { soundTrack.insertEmptyTimeRange(CMTimeRange(start: filled, end: cursor)) }
                    let stretch = CMTimeRange(start: .zero, duration: range.duration)
                    soundInserted = (try? soundTrack.insertTimeRange(stretch, of: effected, at: cursor)) != nil
                } else if let soundTrack, let sound {
                    let filled = soundTrack.timeRange.end
                    if CMTimeCompare(cursor, filled) > 0 { soundTrack.insertEmptyTimeRange(CMTimeRange(start: filled, end: cursor)) }
                    soundInserted = (try? soundTrack.insertTimeRange(range, of: sound, at: cursor)) != nil
                }
            } else {
                video.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: range.duration))
            }
            var length = range.duration
            if let curve = segment.speedCurve {
                // Along a curve: stretched a short step at a time, each at the curve's speed there.
                length = scaleAlong(
                    curve, inserted: range.duration, at: cursor, video: recording(segment.sourceID) != nil ? video : nil,
                    sound: soundInserted ? soundTrack : nil
                )
            } else if abs(segment.speed - 1) > 0.000_1 {
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

    /// Steps a curve is played in, per edited second: the speed changes 30 times a second, a frame at a time, so neither the
    /// picture nor the sound shows a step.
    static let curveStepsPerSecond = 30.0
    /// Most steps one curved clip is played in (50 s at 30 a second; a longer clip takes longer steps), so a long clip never
    /// makes a composition of tens of thousands of pieces.
    static let mostCurveSteps = 1500

    /// Stretches the piece just inserted at `start` (`inserted` long, as filmed) along `curve`, on the
    /// tracks given: step by step, each step of the recording scaled to the time the curve gives it. Returns its length in the
    /// edit.
    private static func scaleAlong(
        _ curve: SpeedCurve, inserted: CMTime, at start: CMTime, video: AVMutableCompositionTrack?, sound: AVMutableCompositionTrack?
    ) -> CMTime {
        let scale: CMTimeScale = 60_000
        let sourceLength = inserted.seconds
        let edited = curve.editedLength(sourceLength: sourceLength)
        let steps = min(mostCurveSteps, max(4, Int((edited * curveStepsPerSecond).rounded(.up))))
        var position = start
        var sourceDone = CMTime.zero
        var editedDone = CMTime.zero
        for step in 1...steps {
            let editedEnd = CMTime(seconds: edited * Double(step) / Double(steps), preferredTimescale: scale)
            let sourceEnd = step == steps
                ? inserted
                : CMTime(seconds: curve.sourceOffset(forEdited: editedEnd.seconds, sourceLength: sourceLength), preferredTimescale: scale)
            let piece = CMTimeRange(start: position, duration: CMTimeSubtract(sourceEnd, sourceDone))
            let target = CMTimeSubtract(editedEnd, editedDone)
            guard CMTimeCompare(piece.duration, .zero) > 0, CMTimeCompare(target, .zero) > 0 else { continue }
            video?.scaleTimeRange(piece, toDuration: target)
            sound?.scaleTimeRange(piece, toDuration: target)
            position = CMTimeAdd(position, target)
            sourceDone = sourceEnd
            editedDone = editedEnd
        }
        return CMTimeSubtract(position, start)
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

        var shape: EditFraming.Shape { EditFraming.Shape(transform: transform, uprightSize: uprightSize) }

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

    /// Stretches cut again where the main track moves to another recording (and, in a dissolve
    /// between two recordings, at its cut) and where a section with a slow zoom or an Animation
    /// starts or ends, so each stretch reads one recording on each track and has one zoom and one
    /// animation, and where the next clip has another look or background (`EditSegment.look`),
    /// steadiness or shape (Rotate, Mirror, Crop), so each stretch is drawn one way. An edit of the
    /// take alone without any of those stays as it was.
    static func splitBySource(
        _ stretches: [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)], in timeline: EditTimeline
    ) -> [(range: CMTimeRange, dissolve: TransitionWindow?, showsMedia: Bool)] {
        let segments = timeline.segments
        var marks: [CMTime] = []
        for index in segments.indices.dropFirst()
        where segments[index].sourceID != segments[index - 1].sourceID || segments[index].zoom != nil || segments[index - 1].zoom != nil
            || segments[index].look != segments[index - 1].look || segments[index].stabilization != segments[index - 1].stabilization
            || segments[index].orientation != segments[index - 1].orientation || segments[index].animates || segments[index - 1].animates {
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

    /// The transitions of the edit as made, where the item plays them: measured on the edit itself (clips grown to the whole
    /// recording for the editor's preview would give a transition more room than the export has), then moved by the lead-in
    /// and the pieces the growing put before them (`RenderPlan`).
    static func transitionWindows(of made: EditTimeline, reachesWholeRecording: Bool) -> [TransitionWindow] {
        let windows = TransitionWindow.windows(in: made)
        guard reachesWholeRecording else { return windows }
        return windows.map { $0.shifted(by: made.reachableLeadIn, pieces: made.reachableLeadPieces) }
    }

    /// Each piece's zoom (by its index in the edit as made), over the piece as made and where the item plays it.
    static func zoomWindows(of made: EditTimeline, reachesWholeRecording: Bool) -> [ZoomWindow?] {
        let leadIn = reachesWholeRecording ? made.reachableLeadIn : 0
        return made.segments.indices.map { index in
            let segment = made.segments[index]
            return segment.zoom.map {
                ZoomWindow(zoom: $0, start: leadIn + made.editedStart(ofSegmentAt: index), duration: segment.duration, amount: segment.zoomAmount)
            }
        }
    }

    /// Each piece's Animation, measured on the edit as made (as its zoom), placed where the drawing plays it.
    static func animationWindows(of made: EditTimeline, reachesWholeRecording: Bool) -> [ClipAnimationWindow?] {
        let leadIn = reachesWholeRecording ? made.reachableLeadIn : 0
        return made.segments.indices.map { index in
            let segment = made.segments[index]
            guard segment.animationIn != nil || segment.animationOut != nil else { return nil }
            return ClipAnimationWindow(
                start: leadIn + made.editedStart(ofSegmentAt: index), duration: segment.duration, entrance: segment.animationIn,
                exit: segment.animationOut
            )
        }
    }

    /// The crop at the requested quality, with even dimensions. Never upscaled (`ExportFrameSize`, the rule the app's labels read too).
    static func outputSize(for crop: CGSize, shortSide: CGFloat?) -> CGSize {
        ExportFrameSize.size(ofCrop: crop, shortSide: shortSide)
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
    /// (reading both tracks), the rest from the main track alone, also cut where a video over the take
    /// (`media`, edited seconds) starts and ends, so the media track is only read while one shows. They
    /// follow on without gaps from the start to `duration`.
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
    /// `MediaOverlay.simultaneousLimit`), each piece of each (`MediaOverlay.pieces`) from its second of the file for as long
    /// as it shows; one that can't be read, or would need one track too many, is left out rather than failing the edit. A
    /// support gets the split screen's areas; its sound, like any video's, plays only when turned up and not muted for all.
    private static func placeMedia(
        of edit: TakeEdit, frame size: CGSize, in composition: AVMutableComposition, duration: CMTime
    ) async -> (tracks: [AVMutableCompositionTrack], frames: [MediaFrame], sounds: [(track: AVMutableCompositionTrack, volume: Float)]) {
        let placed = edit.placedMedia(in: edit.timeline)
        guard !placed.isEmpty else { return ([], [], []) }
        let end = duration.seconds
        var frames: [MediaFrame] = []
        var sounds: [(track: AVMutableCompositionTrack, volume: Float)] = []
        var tracks: [(track: AVMutableCompositionTrack, filled: CMTime)] = []
        for entry in placed {
            let url = EditMediaFiles.url(for: entry.media.fileName)
            // The pieces inside the edit.
            let shown = entry.pieces.compactMap { piece -> MediaPiece? in
                guard piece.edited.start < end - MediaOverlay.shortestPiece else { return nil }
                var piece = piece
                piece.edited.end = min(piece.edited.end, end)
                return piece
            }
            guard let firstShown = shown.first, let lastShown = shown.last else { continue }
            let span = TimeSpan(start: firstShown.edited.start, end: lastShown.edited.end)
            let areas = entry.media.layout == .split
                ? SplitPlacement.areas(edit.splitScreen.layout(id: entry.media.splitLayoutID), in: size)
                : nil
            let topLeft = areas?.support ?? MediaPlacement.rect(for: entry.media, in: size)
            // Core Image measures y from the bottom.
            let rect = CGRect(x: topLeft.minX, y: size.height - topLeft.maxY, width: topLeft.width, height: topLeft.height)
            var frame: MediaFrame
            switch entry.media.kind {
            case .photo:
                guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { continue }
                frame = MediaFrame(span: span, rect: rect, image: image, transform: .identity, layer: entry.media.stackOrder)
            case .video:
                let asset = AVURLAsset(url: url)
                guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                      let transform = try? await source.load(.preferredTransform),
                      let track = videoTrack(from: span.start, among: &tracks, in: composition),
                      insert(shown, of: source, into: track, among: &tracks) else { continue }
                if !edit.splitScreen.mutesMedia, let volume = entry.media.audioVolume, volume > 0,
                   let sound = await placeSound(of: asset, pieces: shown, in: composition) {
                    sounds.append((sound, Float(min(max(volume, 0), 1))))
                }
                frame = MediaFrame(span: span, rect: rect, image: nil, transform: transform, trackID: track.trackID, layer: entry.media.stackOrder)
            }
            if shown.count > 1 { frame.pieces = shown.map(\.edited) }
            frame.frameSize = size
            frame.mediaID = entry.media.id
            frame.filePieces = shown
            frame.blurs = edit.blurRegions.filter { $0.target.mediaID == entry.media.id }
            frame.areaFraming = (areas == nil ? entry.media.pictureFraming : entry.media.areaFraming) ?? AreaFraming()
            if let areas {
                frame.areas = areas
            } else {
                frame.mask = entry.media.mask
                frame.opacity = min(max(entry.media.opacity ?? 1, 0.1), 1)
                frame.motion = Self.motion(of: entry.media, rect: topLeft, span: span, in: size)
            }
            frames.append(frame)
        }
        let used = tracks.map(\.track).filter { track in frames.contains { $0.trackID == track.trackID } }
        for (track, _) in tracks where !used.contains(where: { $0.trackID == track.trackID }) { composition.removeTrack(track) }
        return (used, frames, sounds)
    }

    /// The first media track free by `start` (edited seconds), or a new one while there are fewer than
    /// `MediaOverlay.simultaneousLimit`.
    private static func videoTrack(
        from start: TimeInterval, among tracks: inout [(track: AVMutableCompositionTrack, filled: CMTime)], in composition: AVMutableComposition
    ) -> AVMutableCompositionTrack? {
        let at = CMTime(seconds: start, preferredTimescale: 600)
        if let free = tracks.first(where: { CMTimeCompare($0.filled, at) <= 0 }) { return free.track }
        guard tracks.count < MediaOverlay.simultaneousLimit,
              let added = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        tracks.append((added, .zero))
        return added
    }

    /// Lays each piece of a video on `track` from its second of the file, empty in between; false (and nothing laid) when the
    /// file can't give one.
    private static func insert(
        _ pieces: [MediaPiece], of source: AVAssetTrack, into track: AVMutableCompositionTrack,
        among tracks: inout [(track: AVMutableCompositionTrack, filled: CMTime)]
    ) -> Bool {
        guard let slot = tracks.firstIndex(where: { $0.track.trackID == track.trackID }) else { return false }
        let before = tracks[slot].filled
        var filled = before
        for piece in pieces {
            let start = CMTime(seconds: piece.edited.start, preferredTimescale: 600)
            let end = CMTime(seconds: piece.edited.end, preferredTimescale: 600)
            guard CMTimeCompare(end, start) > 0 else { continue }
            if CMTimeCompare(start, filled) > 0 { track.insertEmptyTimeRange(CMTimeRange(start: filled, end: start)) }
            do {
                let at = CMTimeMaximum(start, filled)
                let inFile = CMTime(seconds: piece.fileStart, preferredTimescale: 600)
                try track.insertTimeRange(CMTimeRange(start: inFile, duration: end - at), of: source, at: at)
            } catch {
                // What this video laid so far comes off again; the track is as it was.
                if CMTimeCompare(track.timeRange.end, before) > 0 { track.removeTimeRange(CMTimeRange(start: before, end: track.timeRange.end)) }
                return false
            }
            filled = CMTimeMaximum(filled, end)
        }
        tracks[slot].filled = filled
        return true
    }

    /// A photo's or video's keyframes and preset, over where its window is (`rect`, from the top left); nil when nothing moves it.
    private static func motion(of media: MediaOverlay, rect: CGRect, span: TimeSpan, in size: CGSize) -> OverlayMotion? {
        let keyframes = media.keyframes ?? []
        guard !keyframes.isEmpty || media.animation != nil else { return nil }
        let center = OverlayPoint(x: Double(rect.midX / max(1, size.width)), y: Double(rect.midY / max(1, size.height)))
        return OverlayMotion(keyframes, animation: media.animation, length: span.duration, base: OverlayMotion.State(center: center, scale: 1, opacity: 1))
    }

    /// A video's own sound on a sound track of its own: each piece from its second of the file, as long as it shows and the
    /// file has sound.
    private static func placeSound(
        of asset: AVURLAsset, pieces: [MediaPiece], in composition: AVMutableComposition
    ) async -> AVMutableCompositionTrack? {
        guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
              let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return nil }
        let length = (try? await source.load(.timeRange).end.seconds) ?? .greatestFiniteMagnitude
        var filled = CMTime.zero
        for piece in pieces {
            let available = min(piece.edited.duration, length - piece.fileStart)
            guard available > MediaOverlay.shortestPiece else { continue }
            let start = CMTime(seconds: piece.edited.start, preferredTimescale: 600)
            if CMTimeCompare(start, filled) > 0 { track.insertEmptyTimeRange(CMTimeRange(start: filled, end: start)) }
            let range = CMTimeRange(
                start: CMTime(seconds: piece.fileStart, preferredTimescale: 600), duration: CMTime(seconds: available, preferredTimescale: 600)
            )
            guard (try? track.insertTimeRange(range, of: source, at: CMTimeMaximum(start, filled))) != nil else { continue }
            filled = track.timeRange.end
        }
        guard CMTimeCompare(filled, .zero) > 0 else {
            composition.removeTrack(track)
            return nil
        }
        return track
    }

    /// Where the main video plays quieter (or silent) because a support shows with the main's volume lowered.
    static func mainSoundWindows(of edit: TakeEdit) -> [MainSoundLevels.Window] {
        edit.placedMedia(in: edit.timeline).flatMap { entry -> [MainSoundLevels.Window] in
            guard let volume = entry.media.mainVolume else { return [] }
            let factor = Float(min(max(volume, 0), 1))
            return entry.pieces.map { MainSoundLevels.Window(span: $0.edited, factor: factor) }
        }
    }

    /// Each music clip that isn't muted on its own sound track, on the edit's seconds within
    /// `window`, with how loud it is over time: one that ducks goes down under `speech` (a clip saved before `MusicClip.duck`
    /// under what it always went down under).
    private static func placeMusic(
        of edit: TakeEdit, window: TimeSpan, speech: SpokenSpans, in composition: AVMutableComposition
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
            let spoken = clip.duck == nil ? speech.legacySpans : speech.spans
            let points = MusicEnvelope.points(
                span: TimeSpan(start: start, end: end), volume: clip.volume, fadeIn: clip.fadeIn, fadeOut: clip.fadeOut,
                speech: clip.ducksUnderVoice ? spoken : nil, duck: clip.duck
            )
            placed.append((track, points))
        }
        return placed
    }

    /// Each voice-over on its own sound track, from where it starts (and from its trimmed start in the recording), cut at the
    /// end of the edit.
    private static func placeVoiceOvers(
        of edit: TakeEdit, in composition: AVMutableComposition
    ) async throws -> [(track: AVMutableCompositionTrack, volume: Float)] {
        var voices: [(track: AVMutableCompositionTrack, volume: Float)] = []
        var effectAssets: [AVURLAsset] = []
        defer { withExtendedLifetime(effectAssets) {} }
        for clip in edit.voiceOvers {
            guard let span = clip.editedSpan(in: edit.timeline) else { continue }
            let asset = AVURLAsset(url: EditMediaFiles.url(for: clip.fileName))
            // With a voice effect, its recording through it (`+VoiceEffects`), as long as the recording.
            let effected = try await effectSound(of: clip, keeping: &effectAssets)
            let recorded = effected == nil ? try? await asset.loadTracks(withMediaType: .audio).first : nil
            guard let source = effected ?? recorded,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }
            let range = CMTimeRange(
                start: CMTime(seconds: clip.offset ?? 0, preferredTimescale: 600), duration: CMTime(seconds: span.duration, preferredTimescale: 600)
            )
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

    /// The take's sound level along the edit on one sound track: each clip at its volume (silent
    /// while muted, or where it plays on another track: `plays` says which clips this track
    /// carries), the dips at the cuts scaled to it, a clip's own fades from and to silence (as
    /// long as the dip there at least), and a quick ramp where two clips that run on from each
    /// other have different volumes. A `Fade` without duration sets the level at its start.
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
        let uniform = segments.indices.allSatisfy { level($0) == 1 && segments[$0].soundFadeIn <= 0 && segments[$0].soundFadeOut <= 0 }
        var fades: [Fade] = []
        var elapsed: TimeInterval = 0
        // Where the sound was at the end of the clip before: its level, or silence after its fade out.
        var reached: Float = 1
        for (index, segment) in segments.enumerated() {
            let end = elapsed + segment.duration
            let length = min(cutFade, segment.duration / 2)
            let volume = level(index)
            let fadeIn = volume > 0 ? min(EditSegment.clampedFade(segment.soundFadeIn), segment.duration) : 0
            let fadeOut = volume > 0 ? min(EditSegment.clampedFade(segment.soundFadeOut), segment.duration - fadeIn) : 0
            // How long the sound takes to come up at the start: a dip's half, a cut's click guard, or none.
            var rise: TimeInterval?
            if let dip = dips[index] {
                rise = dip.halfDuration
            } else if index > 0, !timeline.isSeamless(index) {
                rise = length
            }
            // How long the clip's opening ramp lasts, whichever it is: the fade out waits for it (two ramps at once crash).
            var opening: TimeInterval = 0
            if fadeIn > 0 || rise != nil {
                opening = min(max(fadeIn, rise ?? 0), segment.duration)
                fades.append(Fade(start: elapsed, duration: opening, fromVolume: 0, toVolume: volume))
            } else if !uniform {
                let previous = index > 0 ? reached : volume
                if index > 0, previous != volume {
                    opening = length
                    fades.append(Fade(start: elapsed, duration: length, fromVolume: previous, toVolume: volume))
                } else {
                    fades.append(Fade(start: elapsed, duration: 0, fromVolume: volume, toVolume: volume))
                }
            }
            var fall: TimeInterval?
            if let dip = dips[index + 1] {
                fall = dip.halfDuration
            } else if index < segments.count - 1, !timeline.isSeamless(index + 1) {
                fall = length
            }
            if fadeOut > 0 || fall != nil {
                let out = min(max(fadeOut, fall ?? 0), max(0, segment.duration - opening))
                fades.append(Fade(start: end - out, duration: out, fromVolume: volume, toVolume: 0))
            }
            reached = fadeOut > 0 ? 0 : volume
            elapsed = end
        }
        return fades
    }

    /// A music clip's envelope as volume changes: its first level from the start, then a ramp between each two points.
    static func musicLevels(_ points: [MusicEnvelope.Point]) -> [Fade] {
        guard let first = points.first else { return [] }
        var fades = [Fade(start: 0, duration: 0, fromVolume: Float(first.volume), toVolume: Float(first.volume))]
        for (from, to) in zip(points, points.dropFirst()) where to.time - from.time > 0.000_1 {
            fades.append(Fade(start: from.time, duration: to.time - from.time, fromVolume: Float(from.volume), toVolume: Float(to.volume)))
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
            VolumeRamp.apply(VolumeRamp.scheduled(take.levels), to: parameters)
            inputs.append(parameters)
        }
        for voice in voices {
            let parameters = AVMutableAudioMixInputParameters(track: voice.track)
            parameters.setVolume(voice.volume, at: .zero)
            inputs.append(parameters)
        }
        for clip in music {
            let parameters = AVMutableAudioMixInputParameters(track: clip.track)
            VolumeRamp.apply(VolumeRamp.scheduled(musicLevels(clip.points)), to: parameters)
            inputs.append(parameters)
        }
        guard !inputs.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = inputs
        return mix
    }
}
