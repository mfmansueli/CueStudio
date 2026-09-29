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
    /// Clean Up's findings: pauses, filler words and possible retakes. Suggestions only: removing
    /// one cuts it from the timeline.
    var suggestions: [CleanUpSuggestion] = []
    /// Clean Up has listened to the take (so an empty list means it found nothing).
    var cleanUpAnalyzed = false

    // MARK: Audio
    /// 0 to 1.5 (150%).
    var volume: Double = 1
    var enhancesVoice = true
    var reducesNoise = false

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
    /// Timed to the original recording.
    var captions: [CaptionCue] = []
    /// What speech recognition heard, word by word, before any correction; nil until captions are
    /// made from the voice.
    var captionTranscript: CaptionTranscript?
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
    /// times shows only the words still in the edit, each at its edited time.
    var editedCaptions: [CaptionCue] {
        captions.compactMap { cue in
            if !cue.words.isEmpty {
                let words = cue.words.compactMap { word -> CaptionWord? in
                    // A word shows when its middle is still in the edit.
                    let middle = (word.start + word.end) / 2
                    guard timeline.editedTime(forSource: middle) != nil,
                          let start = timeline.editedTime(forSource: word.start) ?? timeline.editedTime(forSource: middle) else { return nil }
                    let end = timeline.editedTime(forSource: max(word.start, word.end - 0.01)).map { $0 + 0.01 } ?? timeline.editedTime(forSource: middle) ?? start
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
            guard let start = timeline.editedTime(forSource: cue.start) ?? timeline.editedTime(forSource: cue.end - 0.05) else { return nil }
            let end = timeline.editedTime(forSource: cue.end - 0.05).map { $0 + 0.05 } ?? start + (cue.end - cue.start)
            var mapped = cue
            mapped.start = start
            mapped.end = max(start + CaptionCue.minimumDuration, end)
            return mapped
        }
    }

    /// Whether anything visible or audible differs from the original.
    func differs(from original: AspectRatio) -> Bool {
        var untouched = TakeEdit(sourceDuration: sourceDuration, aspect: original)
        untouched.captions = captions
        untouched.captionTranscript = captionTranscript
        untouched.captionLanguage = captionLanguage
        untouched.suggestions = suggestions
        untouched.cleanUpAnalyzed = cleanUpAnalyzed
        if timeline.isWhole { untouched.timeline = timeline }
        return self != untouched
    }

    /// Texts that show somewhere in `timeline`, with where (edited seconds), in order.
    func editedTexts(in timeline: EditTimeline) -> [(text: TextOverlay, span: TimeSpan)] {
        texts.compactMap { text in
            guard !text.isEmpty, let span = timeline.editedSpan(forSource: text.span) else { return nil }
            return (text, span)
        }
    }

    /// Photos and videos that show somewhere in `timeline`, with where (edited seconds), in order.
    /// A video never shows longer than it lasts.
    func editedMedia(in timeline: EditTimeline) -> [(media: MediaOverlay, span: TimeSpan)] {
        media.compactMap { item -> (media: MediaOverlay, span: TimeSpan)? in
            guard var span = timeline.editedSpan(forSource: item.span) else { return nil }
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

    /// Media files (B-roll, voice-overs, a cover photo) the edit reads.
    var mediaFileNames: Set<String> {
        var names = Set(media.map(\.fileName) + voiceOvers.map(\.fileName))
        if case .photo(let name)? = cover?.source { names.insert(name) }
        return names
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case timeline, suggestions, cleanUpAnalyzed, volume, enhancesVoice, reducesNoise, exposure, contrast, warmth, filter
        case aspect, cropOffset, showsCaptions, captionStyle, captionLook, captionPreset, captionPosition, captions
        case captionTranscript, captionLanguage
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
            suggestions = try container.decodeIfPresent([CleanUpSuggestion].self, forKey: .suggestions) ?? []
            cleanUpAnalyzed = try container.decodeIfPresent(Bool.self, forKey: .cleanUpAnalyzed) ?? false
        } else {
            (timeline, suggestions) = try Self.legacyTimeline(from: decoder)
        }
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        enhancesVoice = try container.decodeIfPresent(Bool.self, forKey: .enhancesVoice) ?? true
        reducesNoise = try container.decodeIfPresent(Bool.self, forKey: .reducesNoise) ?? false
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
        captionLanguage = try? container.decodeIfPresent(CueLanguage.self, forKey: .captionLanguage)
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
