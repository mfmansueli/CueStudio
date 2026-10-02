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
    static let volumeRange: ClosedRange<Double> = 0...1.5
    static let adjustmentRange: ClosedRange<Double> = -100...100
    static let cropOffsetRange: ClosedRange<Double> = -1...1

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
    /// Pauses: only silences at least this long are listed ("Pauses longer than").
    var pauseThreshold: TimeInterval = 0.7

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
    /// The creator's music and sounds, under the video.
    var music: [MusicClip] = []
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
    /// Photos and videos over the take (B-roll), one at a time, pinned to the recording.
    var media: [MediaOverlay] = []
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
        CaptionTimelineMapping.instances(lines, in: timeline)
    }

    /// Whether anything visible or audible differs from the original.
    func differs(from original: AspectRatio) -> Bool {
        var untouched = TakeEdit(sourceDuration: sourceDuration, aspect: original)
        untouched.captions = captions
        untouched.captionTranscript = captionTranscript
        untouched.sourceTranscripts = sourceTranscripts
        untouched.captionLanguage = captionLanguage
        untouched.suggestions = suggestions
        untouched.cleanUpAnalyzed = cleanUpAnalyzed
        if timeline.isWhole { untouched.timeline = timeline }
        return self != untouched
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

    /// Photos and videos that show somewhere in `timeline`, with where (edited seconds), in order.
    /// A video never shows longer than it lasts.
    func editedMedia(in timeline: EditTimeline) -> [(media: MediaOverlay, span: TimeSpan)] {
        media.compactMap { item -> (media: MediaOverlay, span: TimeSpan)? in
            guard var span = Self.editedSpan(item.span, anchor: item.clipAnchor, in: timeline) else { return nil }
            span.end = min(span.end, span.start + item.longestDuration)
            return (item, span)
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
        return names
    }

    /// A dial is off zero, here or on a clip.
    private var usesAdjustDials: Bool {
        [exposure, contrast, warmth, saturation, highlights, shadows, sharpness].contains { $0 != 0 }
            || timeline.segments.contains { $0.look?.overridesAdjustment ?? false }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case timeline, sources, suggestions, cleanUpAnalyzed, volume, enhancesVoice, reducesNoise,
        audioVersion, voiceEnhancement, noiseReduction, music, backgrounds, exposure, contrast, warmth, filter
        case saturation, highlights, shadows, sharpness, filterAmount, cropFit, pauseThreshold
        case vibrance, tint, autoCorrection, autoAmount, lookVersion
        case aspect, cropOffset, showsCaptions, captionStyle, captionLook, captionPreset, captionPosition, captions
        case captionTranscript, sourceTranscripts, captionLanguage, captionAnimation, captionTranslations, captionDisplay
        case captionCollection
        case texts, media, voiceOvers, creatorStyle, textLook, textPreset, cover
    }

    /// Edits saved before the timeline had pieces: trim handles, cut points, deleted sections and
    /// silences that were either all cut or all kept.
    private enum LegacyKeys: String, CodingKey {
        case sourceDuration, trimStart, trimEnd, splits, removed, silences, removesSilences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let timeline = try container.decodeIfPresent(EditTimeline.self, forKey: .timeline) {
            self.timeline = timeline
            sources = (try? container.decodeIfPresent([ClipSource].self, forKey: .sources)) ?? []
            suggestions = try container.decodeIfPresent([CleanUpSuggestion].self, forKey: .suggestions) ?? []
            cleanUpAnalyzed = try container.decodeIfPresent(Bool.self, forKey: .cleanUpAnalyzed) ?? false
        } else {
            (timeline, suggestions) = try Self.legacyTimeline(from: decoder)
        }
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        enhancesVoice = try container.decodeIfPresent(Bool.self, forKey: .enhancesVoice) ?? true
        reducesNoise = try container.decodeIfPresent(Bool.self, forKey: .reducesNoise) ?? false
        // Edits saved before the levels keep the first treatment.
        audioVersion = (try? container.decodeIfPresent(Int.self, forKey: .audioVersion)) ?? 1
        voiceEnhancement = (try? container.decodeIfPresent(AudioStrength.self, forKey: .voiceEnhancement)) ?? (enhancesVoice ? .soft : .off)
        noiseReduction = (try? container.decodeIfPresent(AudioStrength.self, forKey: .noiseReduction)) ?? (reducesNoise ? .soft : .off)
        music = (try? container.decodeIfPresent([MusicClip].self, forKey: .music)) ?? []
        backgrounds = (try? container.decodeIfPresent([RecordingBackground].self, forKey: .backgrounds)) ?? []
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
        autoCorrection = try? container.decodeIfPresent(AutoCorrection.self, forKey: .autoCorrection)
        autoAmount = (try? container.decodeIfPresent(Double.self, forKey: .autoAmount)) ?? 1
        cropFit = (try? container.decodeIfPresent(CropFit.self, forKey: .cropFit)) ?? .fill
        pauseThreshold = (try? container.decodeIfPresent(TimeInterval.self, forKey: .pauseThreshold)) ?? 0.7
        aspect = try container.decode(AspectRatio.self, forKey: .aspect)
        cropOffset = try container.decodeIfPresent(Double.self, forKey: .cropOffset) ?? 0
        showsCaptions = try container.decodeIfPresent(Bool.self, forKey: .showsCaptions) ?? false
        captionCollection = try container.decodeIfPresent(CaptionSettings.self, forKey: .captionCollection)
        captionStyle = try container.decodeIfPresent(CaptionStyle.self, forKey: .captionStyle) ?? .bold
        captionLook = try? container.decodeIfPresent(TextLook.self, forKey: .captionLook)
        captionPreset = try? container.decodeIfPresent(TypePreset.self, forKey: .captionPreset)
        captionPosition = try container.decodeIfPresent(CaptionPosition.self, forKey: .captionPosition) ?? .bottom
        captions = try container.decodeIfPresent([CaptionCue].self, forKey: .captions) ?? []
        captionTranscript = try? container.decodeIfPresent(CaptionTranscript.self, forKey: .captionTranscript)
        sourceTranscripts = (try? container.decodeIfPresent([CaptionTranscript].self, forKey: .sourceTranscripts)) ?? []
        captionLanguage = try? container.decodeIfPresent(CueLanguage.self, forKey: .captionLanguage)
        captionAnimation = (try? container.decodeIfPresent(CaptionAnimation.self, forKey: .captionAnimation)) ?? .line
        captionTranslations = (try? container.decodeIfPresent([CaptionTranslation].self, forKey: .captionTranslations)) ?? []
        captionDisplay = (try? container.decodeIfPresent(CaptionDisplay.self, forKey: .captionDisplay)) ?? .original
        // Added later: edits saved before have none, and a damaged one loses only that part.
        texts = (try? container.decodeIfPresent([TextOverlay].self, forKey: .texts)) ?? []
        media = (try? container.decodeIfPresent([MediaOverlay].self, forKey: .media)) ?? []
        voiceOvers = (try? container.decodeIfPresent([VoiceOverClip].self, forKey: .voiceOvers)) ?? []
        creatorStyle = try? container.decodeIfPresent(CreatorStyle.self, forKey: .creatorStyle)
        textLook = try? container.decodeIfPresent(TextLook.self, forKey: .textLook)
        textPreset = try? container.decodeIfPresent(TypePreset.self, forKey: .textPreset)
        cover = try? container.decodeIfPresent(VideoCover.self, forKey: .cover)
        // An edit saved before the calibrated dials reads them the first way, unless it never used them.
        lookVersion = (try? container.decodeIfPresent(Int.self, forKey: .lookVersion)) ?? (usesAdjustDials ? 1 : LookSettings.currentVersion)
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
