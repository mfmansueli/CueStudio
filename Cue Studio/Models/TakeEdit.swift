//
//  TakeEdit.swift
//  Cue Studio
//

import Foundation

/// Quick edit as a recipe applied on top of the original recording, which is never changed: the
/// timeline (trim, cuts, removed pieces, speed), Clean Up's findings, audio, look, crop, captions,
/// and what is added on top: texts, photos and videos (B-roll), voice-overs and the cover.
/// Preview and export render the same recipe, and the take can be edited again from where it was
/// left.
nonisolated struct TakeEdit: Codable, Hashable, Sendable {
    static let adjustmentRange: ClosedRange<Double> = -100...100

    // MARK: Timeline
    /// What plays: pieces of the recording, in order.
    var timeline: EditTimeline
    /// The montage's other recordings (other takes, videos from Photos); none for one take.
    var sources: [ClipSource] = []
    /// Clean Up's findings: pauses, filler words and possible retakes. Suggestions only: removing
    /// one cuts it from the timeline.
    var suggestions: [CleanUpSuggestion] = []
    /// Clean Up has listened to the take (so an empty list means it found nothing).
    var cleanUpAnalyzed = false
    /// The montage's other recordings Clean Up has listened to (`ClipSource.id`).
    var cleanUpAnalyzedSources: [UUID] = []
    /// The recordings whose pauses Clean Up couldn't hear clearly (a loud background, a soft voice), and how (D16): Pauses says so
    /// again when the editor reopens. A recording heard clearly isn't listed.
    var pauseHearings: [RecordingPauseHearing] = []
    /// Pauses: only silences at least this long are listed ("Pauses longer than").
    var pauseThreshold: TimeInterval = 0.7
    /// Pauses: how much silence a removed pause leaves ("Gap left"); what was already removed keeps its own.
    var pauseGap: PauseGap = .natural
    /// What Clean up learned listening to the take besides its suggestions (whether its words were heard, and in what
    /// language); nil before it listened, or for an edit saved before it was kept.
    var cleanUpHearing: CleanUpHearing?

    // MARK: Audio
    /// 0 to 1.5 (150%): the take's own sound.
    var volume: Double = 1
    /// Version 1 treatment switches (edits made before the levels).
    var enhancesVoice = true
    var reducesNoise = false
    /// Which treatment the take's sound gets (`VoiceProcessing`): 1 for edits made before the
    /// levels below and 2 for edits made before Apple's voice isolation, so they keep sounding as
    /// they did; 3 for new ones.
    var audioVersion = VoiceProcessing.currentVersion
    var voiceEnhancement: AudioStrength = .soft
    var noiseReduction: AudioStrength = .off
    /// Which recordings Studio Voice treats: every one in new edits; only the take in edits saved before montages were.
    var voiceReach: StudioVoiceReach = .standard
    /// "Even out volume": in a montage, the treated recordings' speech is brought to the take's level (within limits, never
    /// clipping), so a quieter take doesn't drop in the middle of the video. Off in edits saved before it.
    var evensOutVoices = true
    /// The creator's music and sounds, under the video.
    var music: [MusicClip] = []
    /// Beats › Snap to beats: the playhead and the handles stick to the music's beats.
    var snapsToBeats = true
    /// Texts, photos or videos, music and voice-overs locked in place on the timeline (Edits' clip lock): no handles, so a
    /// drag can't move or trim what was lined up. Still picked, styled and deleted on purpose.
    var lockedLayers: Set<UUID> = []
    /// Backgrounds blurred or replaced, per recording.
    var backgrounds: [RecordingBackground] = []

    // MARK: Look
    var exposure: Double = 0
    var contrast: Double = 0
    var warmth: Double = 0
    var saturation: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    /// 0 to 100.
    var sharpness: Double = 0
    /// −100…+100 (`CIVibrance`).
    var vibrance: Double = 0
    /// −100…+100, green to magenta.
    var tint: Double = 0
    /// Skin, on the faces of the whole video: smoothing, face light and less shine (`SkinLook`), apart from Adjust. Off in a new
    /// edit; an edit saved with the first smoothing's dial keeps it, on the engine it was made with.
    var skin = SkinLook()
    /// What Auto measured on the take, played before the dials; nil until Auto is used.
    var autoCorrection: AutoCorrection?
    /// How much of `autoCorrection` shows, 0 to 1.
    var autoAmount: Double = 1
    var filter: VideoFilter = .original
    /// How much of the filter shows, 0 to 1.
    var filterAmount: Double = 1
    /// How the dials are read (`LookSettings.version`). An edit saved before the calibrated dials
    /// keeps the first reading, so it looks as it did; one with nothing adjusted starts on the new.
    var lookVersion = LookSettings.currentVersion

    // MARK: Crop
    var aspect: AspectRatio
    /// Where the crop sits inside the recording, -1 (top or left) to 1 (bottom or right).
    var cropOffset: Double = 0
    /// Fill (crop) or Fit (the whole recording, with bars).
    var cropFit: CropFit = .fill
    /// Follow face: a Fill crop moves with the creator's face (`FaceFollowPath`); nil keeps it where `cropOffset` puts it.
    var faceFollow: FaceFollow?

    // MARK: Captions
    var showsCaptions = false
    /// New projects use Cue; decoding an absent key preserves the old renderer and appearance.
    var captionCollection: CaptionSettings? = CaptionSettings()
    /// How captions look in edits made before type presets; `captionLook` replaces it once set.
    var captionStyle: CaptionStyle = .bold
    /// The captions' type (a preset or "My style"); nil draws them in `captionStyle`.
    var captionLook: TextLook?
    /// The preset `captionLook` came from, nil for "My style".
    var captionPreset: TypePreset?
    var captionPosition: CaptionPosition = .bottom
    /// How lines come and go; `.line` (a still line) for edits made before animations.
    var captionAnimation: CaptionAnimation = .line
    /// The captions in other languages, apart from the original lines.
    var captionTranslations: [CaptionTranslation] = []
    /// Which captions show and export.
    var captionDisplay: CaptionDisplay = .original
    /// Timed to the original recording.
    var captions: [CaptionCue] = []
    /// What speech recognition heard, word by word, before any correction; nil until captions are
    /// made from the voice.
    var captionTranscript: CaptionTranscript?
    /// The same for a montage's other recordings.
    var sourceTranscripts: [CaptionTranscript] = []
    /// The language spoken in the take, when the creator picked it for captions; nil listens in
    /// the Voice Following language, or the script's.
    var captionLanguage: CueLanguage?

    // MARK: Added
    /// Texts over the video, pinned to the recording.
    var texts: [TextOverlay] = []
    /// Photos and videos over the take (B-roll, windows, the supports of a split screen), pinned to the recording.
    var media: [MediaOverlay] = []
    /// The split screen's layout, how the main video sits in its area and whether the media's sound plays.
    var splitScreen = SplitScreen()
    /// Faces, plates and other parts of the picture hidden (Blur area), each on its footage's own seconds (`BlurRegion`).
    var blurRegions: [BlurRegion] = []
    /// The look the creator last gave a Blur area in this video: the next new one starts with it (nil: `BlurLook.initial`).
    var blurLook: BlurLook?
    /// The brand kit last put on the video, as it was then.
    var brandKit: AppliedBrandKit?
    /// Narrations recorded over the edit.
    var voiceOvers: [VoiceOverClip] = []
    /// The style picked with the old Style tool (it also set captions and the filter); kept so
    /// edits made with it open as they were. New texts start from `textLook` instead.
    var creatorStyle: CreatorStyle?
    /// The type new texts start from, set when a preset or "My style" goes on every text.
    var textLook: TextLook?
    /// The preset `textLook` came from, nil for "My style".
    var textPreset: TypePreset?
    /// The cover saved with exports; nil when none was chosen.
    var cover: VideoCover?

    init(sourceDuration: TimeInterval, aspect: AspectRatio) {
        timeline = EditTimeline(sourceDuration: sourceDuration)
        self.aspect = aspect
    }

    // MARK: - Timeline

    /// Length of the original recording.
    var sourceDuration: TimeInterval { timeline.sourceDuration }

    /// What plays, in order.
    var keptSpans: [TimeSpan] { timeline.keptSpans }

    var editedDuration: TimeInterval { timeline.editedDuration }

    /// Captions timed to the edited video. Lines said in cut pieces disappear; a line with word
    /// times shows only the words still in the edit, each at its edited time. In an arranged edit
    /// a line shows wherever its part of the recording plays: once per copy of a piece.
    var editedCaptions: [CaptionCue] { editedCaptionInstances.map(\.line) }

    /// `editedCaptions`, each with the line it comes from (a copy of a piece shows the same line
    /// again, under another identity).
    var editedCaptionInstances: [(line: CaptionCue, cueID: UUID)] { editedInstances(of: captions) }

    /// The captions that show (`captionDisplay`), timed to the edit: the main lines (the original
    /// or a translation) and, in bilingual, the translation to show with them.
    var shownCaptions: (main: [CaptionCue], second: [CaptionCue]) {
        let translation = captionDisplay.language.flatMap { language in captionTranslations.first { $0.language == language } }
        guard let translation else { return (editedCaptions, []) }
        let translated = editedInstances(of: translation.lines.map(\.cue)).map(\.line)
        switch captionDisplay {
        case .original: return (editedCaptions, [])
        case .translation: return (translated, [])
        case .bilingual: return (editedCaptions, translated)
        }
    }

    /// Lines timed to the edit, each with the line it comes from.
    func editedInstances(of lines: [CaptionCue]) -> [(line: CaptionCue, cueID: UUID)] {
        CaptionTimelineMapping.instances(lines, in: timeline, voices: captionedVoices)
    }

    /// The videos laid over the take whose own voice is captioned, where they show (`MediaOverlay.captionsItsVoice`).
    var captionedVoices: [CaptionTimelineMapping.Voice] {
        media.filter { $0.captionsItsVoice == true && $0.kind == .video }.map { item in
            CaptionTimelineMapping.Voice(mediaID: item.id, pieces: item.pieces(in: timeline))
        }
    }

    /// Texts that show somewhere in `timeline`, with where (edited seconds), in order.
    func editedTexts(in timeline: EditTimeline) -> [(text: TextOverlay, span: TimeSpan)] {
        texts.compactMap { text in
            guard !text.isEmpty, let span = Self.editedSpan(text.span, anchor: text.clipAnchor, in: timeline) else { return nil }
            return (text, span)
        }
    }

    /// Where something pinned to `span` plays: through its piece when it has one, else through the
    /// take's own seconds.
    static func editedSpan(_ span: TimeSpan, anchor: ClipAnchor?, in timeline: EditTimeline) -> TimeSpan? {
        if let anchor { return timeline.editedSpan(forSource: span, anchoredTo: anchor) }
        return timeline.editedSpan(forSource: span)
    }

    /// How something placed over `edited` (edited seconds) is pinned: to its piece in an arranged
    /// edit, else to the take's own seconds.
    func pin(_ edited: TimeSpan) -> (anchor: ClipAnchor?, span: TimeSpan) {
        Self.pin(edited, in: timeline)
    }

    /// `pin(_:)` on `timeline`.
    static func pin(_ edited: TimeSpan, in timeline: EditTimeline) -> (anchor: ClipAnchor?, span: TimeSpan) {
        guard timeline.isArranged else { return (nil, timeline.sourceSpan(forEdited: edited)) }
        let pinned = timeline.anchoredSpan(forEdited: edited)
        return (pinned.anchor, pinned.span)
    }

    /// Texts, media and voice-overs pinned to their piece where they play now: done once, when the
    /// edit becomes arranged, so moving or copying a piece takes them along.
    mutating func anchorOverlays() {
        let timeline = self.timeline
        for index in texts.indices where texts[index].clipAnchor == nil {
            guard let span = timeline.editedSpan(forSource: texts[index].span) else { continue }
            let pinned = timeline.anchoredSpan(forEdited: span)
            texts[index].clipAnchor = pinned.anchor
            texts[index].span = pinned.span
        }
        for index in media.indices where media[index].clipAnchor == nil {
            // Media that follows the cuts keeps its stretch of the speech, cut-out gaps and all: only the clip holding its
            // start is named, so it shows exactly as before.
            if media[index].followsCuts == true {
                let start = media[index].span.start
                guard let piece = timeline.segments.first(where: { $0.sourceID == nil && $0.sourceEnd > start + 0.000_1 }) else { continue }
                media[index].clipAnchor = ClipAnchor(segmentID: piece.id, sourceID: nil)
                continue
            }
            guard let span = timeline.editedSpan(forSource: media[index].span) else { continue }
            let pinned = timeline.anchoredSpan(forEdited: span)
            media[index].clipAnchor = pinned.anchor
            media[index].span = pinned.span
        }
        for index in voiceOvers.indices where voiceOvers[index].clipAnchor == nil {
            let start = timeline.editedTime(following: voiceOvers[index].anchor)
            guard start < timeline.editedDuration else { continue }
            let pinned = timeline.anchoredSpan(forEdited: TimeSpan(start: start, end: start + 0.05))
            voiceOvers[index].clipAnchor = pinned.anchor
            voiceOvers[index].anchor = pinned.span.start
        }
    }

    /// How media that follows the cuts (`MediaOverlay.followsCuts`) laid over `edited` (edited seconds) is pinned, so its
    /// pieces show exactly there (`MediaOverlay.pieces`): the stretch of the speech under it (in an arranged edit, from the
    /// clip at its start through the clips of the same recording that follow it), and, laid on into another recording's
    /// clip, how long it plays on over it (`tail`).
    func pinMedia(_ edited: TimeSpan) -> (anchor: ClipAnchor?, span: TimeSpan, tail: TimeInterval?) {
        Self.pinMedia(edited, in: timeline)
    }

    /// `pinMedia(_:)` on `timeline`.
    static func pinMedia(_ edited: TimeSpan, in timeline: EditTimeline) -> (anchor: ClipAnchor?, span: TimeSpan, tail: TimeInterval?) {
        guard timeline.isArranged else { return (nil, timeline.sourceSpan(forEdited: edited), nil) }
        let segments = timeline.segments
        let first = timeline.segmentIndex(atEdited: edited.start)
        let anchor = segments[first]
        var pieceStart = timeline.editedStart(ofSegmentAt: first)
        let start = min(anchor.sourceEnd, anchor.sourceStart + anchor.sourceOffset(forEdited: max(0, edited.start - pieceStart)))
        let pin = ClipAnchor(segmentID: anchor.id, sourceID: anchor.sourceID)
        var end = start
        var reached = edited.start
        for index in first..<segments.count {
            let segment = segments[index]
            // Only clips going on with the same recording carry the speech on.
            guard segment.sourceID == anchor.sourceID, index == first || segment.sourceStart >= end - 0.000_1 else { break }
            let segmentEnd = pieceStart + segment.duration
            if edited.end <= segmentEnd + 0.000_1 {
                end = segment.sourceStart + segment.sourceOffset(forEdited: max(0, edited.end - pieceStart))
                return (pin, TimeSpan(start: start, end: max(start, min(segment.sourceEnd, end))), nil)
            }
            end = segment.sourceEnd
            reached = segmentEnd
            pieceStart = segmentEnd
        }
        let tail = edited.end - reached
        return (pin, TimeSpan(start: start, end: end), tail > MediaOverlay.shortestPiece ? tail : nil)
    }

    /// Lays the photo or video at `index` over `edited` (edited seconds), pinned the way it goes with the speech: following
    /// the cuts (`pinMedia`) or, media added before, to the recording as it always was (`pin`).
    mutating func layMedia(at index: Int, over edited: TimeSpan) {
        guard media.indices.contains(index) else { return }
        if media[index].followsCuts == true {
            let pinned = pinMedia(edited)
            media[index].clipAnchor = pinned.anchor
            media[index].span = pinned.span
            media[index].tail = pinned.tail
        } else {
            let pinned = pin(edited)
            media[index].clipAnchor = pinned.anchor
            media[index].span = pinned.span
        }
    }

    /// Photos and videos that show somewhere in `timeline`, with where (edited seconds, from the start of their first piece to
    /// the end of their last), in order. A video never shows longer than its file has left (`MediaOverlay.pieces`).
    func editedMedia(in timeline: EditTimeline) -> [(media: MediaOverlay, span: TimeSpan)] {
        placedMedia(in: timeline).map { ($0.media, $0.span) }
    }

    /// Like `editedMedia`, with each one's pieces: where it shows without a break and which second of its file plays there.
    func placedMedia(in timeline: EditTimeline) -> [(media: MediaOverlay, span: TimeSpan, pieces: [MediaPiece])] {
        media.compactMap { item -> (media: MediaOverlay, span: TimeSpan, pieces: [MediaPiece])? in
            let pieces = item.pieces(in: timeline)
            guard let first = pieces.first, let last = pieces.last else { return nil }
            return (item, TimeSpan(start: first.edited.start, end: last.edited.end), pieces)
        }
        .sorted { $0.span.start < $1.span.start }
    }

    /// The look a new text starts with: the one set on every text, else the old Style tool's,
    /// else its role's preset (Title Cue, Subtitle Minimal, Hook Pop, Callout Label).
    func newText(_ role: TextOverlayRole, span: TimeSpan) -> TextOverlay {
        if let textLook { return TextOverlay(role: role, look: textLook, preset: textPreset, span: span) }
        if let creatorStyle { return TextOverlay(role: role, style: creatorStyle, span: span) }
        let preset = role.defaultPreset
        return TextOverlay(role: role, look: preset.look(for: .title), preset: preset, span: span)
    }

    /// The background effect of the take (`nil`) or another recording, when it changes the picture.
    func background(for sourceID: UUID?) -> BackgroundEffect? {
        backgrounds.first { $0.sourceID == sourceID }.map(\.effect).flatMap { $0.isActive ? $0 : nil }
    }

    /// How a clip is drawn: the take's Adjust and Filters, with what the clip overrides on top.
    func lookSettings(for segment: EditSegment) -> LookSettings {
        LookSettings(self).overridden(by: segment.look)
    }

    /// The background effect a clip is drawn with: its own when it has one (an Original one means
    /// none), else its recording's; nil when none changes the picture.
    func background(for segment: EditSegment) -> BackgroundEffect? {
        if let own = segment.look?.background { return own.isActive ? own : nil }
        return background(for: segment.sourceID)
    }

    /// Sets a recording's background effect.
    mutating func setBackground(_ effect: BackgroundEffect, for sourceID: UUID?) {
        backgrounds.removeAll { $0.sourceID == sourceID }
        // Settings stay while it's Original, so switching back finds them.
        if effect != BackgroundEffect() {
            backgrounds.append(RecordingBackground(sourceID: sourceID, effect: effect))
        }
    }

    /// The recordings the edit plays that Clean Up hasn't listened to yet (nil: the take).
    var recordingsToCleanUp: [UUID?] {
        playedRecordingIDs.filter { id in id.map { !cleanUpAnalyzedSources.contains($0) } ?? !cleanUpAnalyzed }
    }

    /// Whether any music goes down while someone speaks, so the voices need listening to.
    var ducksMusic: Bool {
        music.contains { !$0.isMuted && $0.ducksUnderVoice }
    }

    /// The other recordings the timeline plays.
    var playedSources: [ClipSource] {
        sources.filter { source in timeline.segments.contains { $0.sourceID == source.id } }
    }

    /// How the take's own sound is treated.
    var voiceProcessing: VoiceProcessing {
        VoiceProcessing(
            version: audioVersion, volume: volume, enhancesVoice: enhancesVoice, reducesNoise: reducesNoise,
            enhancement: voiceEnhancement, noise: noiseReduction
        )
    }

    /// Media files (B-roll, voice-overs, a cover photo) the edit reads.
    var mediaFileNames: Set<String> {
        var names = Set(media.map(\.fileName) + voiceOvers.map(\.fileName) + sources.map(\.fileName) + music.map(\.fileName))
        names.formUnion(backgrounds.compactMap(\.effect.imageFileName))
        names.formUnion(timeline.segments.compactMap { $0.look?.background?.imageFileName })
        if case .photo(let name)? = cover?.source { names.insert(name) }
        if case .photo(let name)? = cover?.composition?.split?.source { names.insert(name) }
        return names
    }

    /// A dial is off zero, here or on a clip.
    private var usesAdjustDials: Bool {
        [exposure, contrast, warmth, saturation, highlights, shadows, sharpness].contains { $0 != 0 }
            || timeline.segments.contains { $0.look?.overridesAdjustment ?? false }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case timeline, sources, suggestions, cleanUpAnalyzed, cleanUpAnalyzedSources, pauseHearings, volume, enhancesVoice, reducesNoise,
        audioVersion, voiceEnhancement, noiseReduction, voiceReach, evensOutVoices, music, backgrounds, exposure, contrast, warmth, filter
        case snapsToBeats, lockedLayers
        case saturation, highlights, shadows, sharpness, filterAmount, cropFit, pauseThreshold, pauseGap, cleanUpHearing
        case vibrance, tint, autoCorrection, autoAmount, lookVersion, skin, faceFollow
        case aspect, cropOffset, showsCaptions, captionStyle, captionLook, captionPreset, captionPosition, captions
        case captionTranscript, sourceTranscripts, captionLanguage, captionAnimation, captionTranslations, captionDisplay
        case captionCollection
        case texts, media, voiceOvers, creatorStyle, textLook, textPreset, cover
        case splitScreen, brandKit, blurRegions, blurLook
    }

    /// Edits saved before the timeline had pieces: trim handles, cut points, deleted sections and
    /// silences that were either all cut or all kept.
    private enum LegacyKeys: String, CodingKey {
        case sourceDuration, trimStart, trimEnd, splits, removed, silences, removesSilences
        /// The first smoothing's dial, 0…100, before Skin had a panel of its own: read into `skin`, never written again.
        case skinSmoothing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let report = decoder.decodingReport
        if let timeline = try container.decodeIfPresent(EditTimeline.self, forKey: .timeline) {
            self.timeline = timeline
            sources = container.decodeLossy([ClipSource].self, forKey: .sources)
            suggestions = container.decodeLossy([CleanUpSuggestion].self, forKey: .suggestions)
            cleanUpAnalyzed = try container.decodeIfPresent(Bool.self, forKey: .cleanUpAnalyzed) ?? false
            cleanUpAnalyzedSources = (try? container.decodeIfPresent([UUID].self, forKey: .cleanUpAnalyzedSources)) ?? []
            pauseHearings = container.decodeLossy([RecordingPauseHearing].self, forKey: .pauseHearings)
        } else {
            (timeline, suggestions) = try Self.legacyTimeline(from: decoder)
        }
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        enhancesVoice = try container.decodeIfPresent(Bool.self, forKey: .enhancesVoice) ?? true
        reducesNoise = try container.decodeIfPresent(Bool.self, forKey: .reducesNoise) ?? false
        // Edits saved before the levels keep the first treatment.
        audioVersion = ReadingVersion.audio.read(try? container.decodeIfPresent(Int.self, forKey: .audioVersion))
        voiceEnhancement = (try? container.decodeIfPresent(AudioStrength.self, forKey: .voiceEnhancement)) ?? (enhancesVoice ? .soft : .off)
        noiseReduction = (try? container.decodeIfPresent(AudioStrength.self, forKey: .noiseReduction)) ?? (reducesNoise ? .soft : .off)
        // Edits saved before montages could be treated keep their other recordings as they were.
        voiceReach = (try? container.decodeIfPresent(StudioVoiceReach.self, forKey: .voiceReach)) ?? .takeOnly
        evensOutVoices = (try? container.decodeIfPresent(Bool.self, forKey: .evensOutVoices)) ?? false
        music = container.decodeLossy([MusicClip].self, forKey: .music)
        snapsToBeats = (try? container.decodeIfPresent(Bool.self, forKey: .snapsToBeats)) ?? true
        lockedLayers = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .lockedLayers)) ?? []
        backgrounds = container.decodeLossy([RecordingBackground].self, forKey: .backgrounds)
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 0
        warmth = try container.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
        filter = try container.decodeIfPresent(VideoFilter.self, forKey: .filter) ?? .original
        // Added with the v10 editor: edits saved before have none of them.
        saturation = (try? container.decodeIfPresent(Double.self, forKey: .saturation)) ?? 0
        highlights = (try? container.decodeIfPresent(Double.self, forKey: .highlights)) ?? 0
        shadows = (try? container.decodeIfPresent(Double.self, forKey: .shadows)) ?? 0
        sharpness = (try? container.decodeIfPresent(Double.self, forKey: .sharpness)) ?? 0
        filterAmount = (try? container.decodeIfPresent(Double.self, forKey: .filterAmount)) ?? 1
        // Added with the calibrated look: edits saved before have none of them.
        vibrance = (try? container.decodeIfPresent(Double.self, forKey: .vibrance)) ?? 0
        tint = (try? container.decodeIfPresent(Double.self, forKey: .tint)) ?? 0
        skin = Self.skin(in: container, legacy: try decoder.container(keyedBy: LegacyKeys.self), report: report)
        autoCorrection = container.decodeLenient(AutoCorrection.self, forKey: .autoCorrection, report: report)
        autoAmount = (try? container.decodeIfPresent(Double.self, forKey: .autoAmount)) ?? 1
        cropFit = (try? container.decodeIfPresent(CropFit.self, forKey: .cropFit)) ?? .fill
        // Added with Follow face: edits saved before keep their still crop.
        faceFollow = container.decodeLenient(FaceFollow.self, forKey: .faceFollow, report: report)
        // An "eyeContact" key that edits saved with Eye Contact (removed 22/10/2026) still hold is left unread.
        pauseThreshold = (try? container.decodeIfPresent(TimeInterval.self, forKey: .pauseThreshold)) ?? 0.7
        // Added with "Gap left": edits saved before left the natural gap.
        pauseGap = container.decodeChoice(PauseGap.self, forKey: .pauseGap, unknown: .natural, report: report) ?? .natural
        cleanUpHearing = try? container.decodeIfPresent(CleanUpHearing.self, forKey: .cleanUpHearing)
        aspect = try container.decode(AspectRatio.self, forKey: .aspect)
        cropOffset = try container.decodeIfPresent(Double.self, forKey: .cropOffset) ?? 0
        showsCaptions = try container.decodeIfPresent(Bool.self, forKey: .showsCaptions) ?? false
        captionCollection = container.decodeLenient(CaptionSettings.self, forKey: .captionCollection, report: report)
        captionStyle = try container.decodeIfPresent(CaptionStyle.self, forKey: .captionStyle) ?? .bold
        captionLook = container.decodeLenient(TextLook.self, forKey: .captionLook, report: report)
        captionPreset = try? container.decodeIfPresent(TypePreset.self, forKey: .captionPreset)
        captionPosition = try container.decodeIfPresent(CaptionPosition.self, forKey: .captionPosition) ?? .bottom
        // One line that can't be read never takes the others (or the whole edit) with it.
        captions = container.decodeLossy([CaptionCue].self, forKey: .captions)
        captionTranscript = container.decodeLenient(CaptionTranscript.self, forKey: .captionTranscript, report: report)
        sourceTranscripts = container.decodeLossy([CaptionTranscript].self, forKey: .sourceTranscripts)
        captionLanguage = try? container.decodeIfPresent(CueLanguage.self, forKey: .captionLanguage)
        captionAnimation = (try? container.decodeIfPresent(CaptionAnimation.self, forKey: .captionAnimation)) ?? .line
        captionTranslations = container.decodeLossy([CaptionTranslation].self, forKey: .captionTranslations)
        captionDisplay = (try? container.decodeIfPresent(CaptionDisplay.self, forKey: .captionDisplay)) ?? .original
        // Added later: edits saved before have none, and a damaged one loses only that part.
        texts = container.decodeLossy([TextOverlay].self, forKey: .texts)
        media = container.decodeLossy([MediaOverlay].self, forKey: .media)
        splitScreen = container.decodeLenient(SplitScreen.self, forKey: .splitScreen, report: report) ?? SplitScreen()
        brandKit = container.decodeLenient(AppliedBrandKit.self, forKey: .brandKit, report: report)
        blurRegions = container.decodeLossy([BlurRegion].self, forKey: .blurRegions)
        blurLook = try? container.decodeIfPresent(BlurLook.self, forKey: .blurLook)
        voiceOvers = container.decodeLossy([VoiceOverClip].self, forKey: .voiceOvers)
        creatorStyle = try? container.decodeIfPresent(CreatorStyle.self, forKey: .creatorStyle)
        textLook = container.decodeLenient(TextLook.self, forKey: .textLook, report: report)
        textPreset = try? container.decodeIfPresent(TypePreset.self, forKey: .textPreset)
        cover = container.decodeLenient(VideoCover.self, forKey: .cover, report: report)
        // An edit saved before the calibrated dials reads them the first way, unless it never used them.
        lookVersion = ReadingVersion.look.read(try? container.decodeIfPresent(Int.self, forKey: .lookVersion), usedOldNumbers: usesAdjustDials)
    }

    /// Skin as saved; an edit saved before it had a panel has the first smoothing's dial, read by the engine it was made with.
    private static func skin(
        in container: KeyedDecodingContainer<CodingKeys>, legacy: KeyedDecodingContainer<LegacyKeys>, report: DecodingReport?
    ) -> SkinLook {
        if container.contains(.skin) { return container.decodeLenient(SkinLook.self, forKey: .skin, report: report) ?? SkinLook() }
        let dial = (try? legacy.decodeIfPresent(Double.self, forKey: .skinSmoothing)) ?? 0
        return SkinLook(smoothing: .firstEngine(dial))
    }

    /// The same pieces an old edit played, and its silences as pause suggestions.
    private static func legacyTimeline(from decoder: Decoder) throws -> (EditTimeline, [CleanUpSuggestion]) {
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let duration = try legacy.decode(TimeInterval.self, forKey: .sourceDuration)
        let start = try legacy.decodeIfPresent(TimeInterval.self, forKey: .trimStart) ?? 0
        let end = try legacy.decodeIfPresent(TimeInterval.self, forKey: .trimEnd) ?? duration
        let splits = try legacy.decodeIfPresent([TimeInterval].self, forKey: .splits) ?? []
        let removed = try legacy.decodeIfPresent([TimeSpan].self, forKey: .removed) ?? []
        let silences = try legacy.decodeIfPresent([TimeSpan].self, forKey: .silences) ?? []
        let removesSilences = try legacy.decodeIfPresent(Bool.self, forKey: .removesSilences) ?? false

        let points = [start] + splits.filter { $0 > start && $0 < end }.sorted() + [end]
        var kept = zip(points, points.dropFirst())
            .map { TimeSpan(start: $0, end: $1) }
            .filter { !removed.contains($0) }
        if removesSilences { kept = kept.flatMap { $0.subtracting(silences) } }
        let pauses = silences.map { CleanUpSuggestion(kind: .pause, span: $0, confidence: 1) }
        return (EditTimeline(sourceDuration: duration, keeping: kept), pauses)
    }
}
