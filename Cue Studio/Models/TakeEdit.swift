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

    // MARK: Audio
    /// 0 to 1.5 (150%): the take's own sound.
    var volume: Double = 1
    /// Version 1 treatment switches (edits made before the levels).
    var enhancesVoice = true
    var reducesNoise = false
    /// Which treatment the take's sound gets (`VoiceProcessing`): 1 for edits made before the
    /// levels below, so they keep sounding as they did; 2 for new ones.
    var audioVersion = 2
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
    var filter: VideoFilter = .original

    // MARK: Crop
    var aspect: AspectRatio
    /// Where the crop sits inside the recording, -1 (top or left) to 1 (bottom or right).
    var cropOffset: Double = 0

    // MARK: Captions
    var showsCaptions = false
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
        guard timeline.isArranged else {
            return lines.compactMap { cue in Self.mapped(cue, in: timeline, piece: nil).map { ($0, cue.id) } }
        }
        var result: [(line: CaptionCue, cueID: UUID)] = []
        for cue in lines {
            var first = true
            for index in timeline.segments.indices where timeline.segments[index].sourceID == cue.sourceID {
                guard timeline.segments[index].span.overlaps(cue.span), var line = Self.mapped(cue, in: timeline, piece: index) else { continue }
                if !first { line.id = Self.instanceID(cue.id, timeline.segments[index].id) }
                first = false
                result.append((line, cue.id))
            }
        }
        return result.sorted { $0.line.start < $1.line.start }
    }

    /// `cue` in the edit: in the whole timeline, or only in the piece at `piece` (arranged).
    private static func mapped(_ cue: CaptionCue, in timeline: EditTimeline, piece: Int?) -> CaptionCue? {
        func edited(_ time: TimeInterval) -> TimeInterval? {
            guard let piece else { return timeline.editedTime(forSource: time) }
            let segment = timeline.segments[piece]
            guard segment.sourceStart - 0.000_001 <= time, time <= segment.sourceEnd + 0.000_001 else { return nil }
            return timeline.editedStart(ofSegmentAt: piece) + (time - segment.sourceStart) / segment.speed
        }
        if !cue.words.isEmpty {
            let words = cue.words.compactMap { word -> CaptionWord? in
                // A word shows when its middle is still in the edit.
                let middle = (word.start + word.end) / 2
                guard let at = edited(middle), let start = edited(word.start) ?? Optional(at) else { return nil }
                let end = edited(max(word.start, word.end - 0.01)).map { $0 + 0.01 } ?? at
                return CaptionWord(text: word.text, start: start, end: max(start, end), isEstimated: word.isEstimated)
            }
            guard let first = words.first, let last = words.last else { return nil }
            var mapped = cue
            mapped.words = words
            if words.count != cue.words.count { mapped.text = CaptionText.joined(words.map(\.text)) }
            mapped.start = first.start
            mapped.end = max(first.start + CaptionCue.minimumDuration, last.end)
            return mapped
        }
        guard let start = edited(cue.start) ?? edited(cue.end - 0.05) else { return nil }
        let end = edited(cue.end - 0.05).map { $0 + 0.05 } ?? start + (cue.end - cue.start)
        var mapped = cue
        mapped.start = start
        mapped.end = max(start + CaptionCue.minimumDuration, end)
        return mapped
    }

    /// A stable identity for a line shown again in a copy of a piece.
    private static func instanceID(_ cue: UUID, _ piece: UUID) -> UUID {
        let a = cue.uuid
        let b = piece.uuid
        return UUID(uuid: (
            a.0 ^ b.0, a.1 ^ b.1, a.2 ^ b.2, a.3 ^ b.3, a.4 ^ b.4, a.5 ^ b.5, a.6 ^ b.6, a.7 ^ b.7,
            a.8 ^ b.8, a.9 ^ b.9, a.10 ^ b.10, a.11 ^ b.11, a.12 ^ b.12, a.13 ^ b.13, a.14 ^ b.14, a.15 ^ b.15
        ))
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
    /// else Cue's own preset.
    func newText(_ role: TextOverlayRole, span: TimeSpan) -> TextOverlay {
        if let textLook { return TextOverlay(role: role, look: textLook, preset: textPreset, span: span) }
        if let creatorStyle { return TextOverlay(role: role, style: creatorStyle, span: span) }
        return TextOverlay(role: role, look: TypePreset.cue.look(for: .title), preset: .cue, span: span)
    }

    /// The background effect of the take (`nil`) or another recording, when it changes the picture.
    func background(for sourceID: UUID?) -> BackgroundEffect? {
        backgrounds.first { $0.sourceID == sourceID }.map(\.effect).flatMap { $0.isActive ? $0 : nil }
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
        if case .photo(let name)? = cover?.source { names.insert(name) }
        return names
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case timeline, sources, suggestions, cleanUpAnalyzed, volume, enhancesVoice, reducesNoise,
        audioVersion, voiceEnhancement, noiseReduction, music, backgrounds, exposure, contrast, warmth, filter
        case aspect, cropOffset, showsCaptions, captionStyle, captionLook, captionPreset, captionPosition, captions
        case captionTranscript, sourceTranscripts, captionLanguage, captionAnimation, captionTranslations, captionDisplay
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
        aspect = try container.decode(AspectRatio.self, forKey: .aspect)
        cropOffset = try container.decodeIfPresent(Double.self, forKey: .cropOffset) ?? 0
        showsCaptions = try container.decodeIfPresent(Bool.self, forKey: .showsCaptions) ?? false
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
