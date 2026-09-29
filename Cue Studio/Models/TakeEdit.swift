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
    var captionStyle: CaptionStyle = .bold
    var captionPosition: CaptionPosition = .bottom
    /// Timed to the original recording.
    var captions: [CaptionCue] = []

    // MARK: Added
    /// Texts over the video, pinned to the recording.
    var texts: [TextOverlay] = []
    /// Photos and videos over the take (B-roll), one at a time, pinned to the recording.
    var media: [MediaOverlay] = []
    /// Narrations recorded over the edit.
    var voiceOvers: [VoiceOverClip] = []
    /// The look applied to the whole video with Style; nil until one is picked. New texts start
    /// from it (Clean without one).
    var creatorStyle: CreatorStyle?
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

    /// Captions timed to the edited video; lines said in cut pieces disappear.
    var editedCaptions: [CaptionCue] {
        captions.compactMap { cue in
            guard let start = timeline.editedTime(forSource: cue.start) ?? timeline.editedTime(forSource: cue.end - 0.05) else { return nil }
            let end = timeline.editedTime(forSource: cue.end - 0.05).map { $0 + 0.05 } ?? start + (cue.end - cue.start)
            return CaptionCue(text: cue.text, start: start, end: max(start + 0.2, end))
        }
    }

    /// Whether anything visible or audible differs from the original.
    func differs(from original: AspectRatio) -> Bool {
        var untouched = TakeEdit(sourceDuration: sourceDuration, aspect: original)
        untouched.captions = captions
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

    /// The style new texts start from.
    var textStyle: CreatorStyle { creatorStyle ?? .clean }

    /// Media files (B-roll, voice-overs, a cover photo) the edit reads.
    var mediaFileNames: Set<String> {
        var names = Set(media.map(\.fileName) + voiceOvers.map(\.fileName))
        if case .photo(let name)? = cover?.source { names.insert(name) }
        return names
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case timeline, suggestions, cleanUpAnalyzed, volume, enhancesVoice, reducesNoise, exposure, contrast, warmth, filter
        case aspect, cropOffset, showsCaptions, captionStyle, captionPosition, captions
        case texts, media, voiceOvers, creatorStyle, cover
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
        captionPosition = try container.decodeIfPresent(CaptionPosition.self, forKey: .captionPosition) ?? .bottom
        captions = try container.decodeIfPresent([CaptionCue].self, forKey: .captions) ?? []
        // Added later: edits saved before have none, and a damaged one loses only that part.
        texts = (try? container.decodeIfPresent([TextOverlay].self, forKey: .texts)) ?? []
        media = (try? container.decodeIfPresent([MediaOverlay].self, forKey: .media)) ?? []
        voiceOvers = (try? container.decodeIfPresent([VoiceOverClip].self, forKey: .voiceOvers)) ?? []
        creatorStyle = try? container.decodeIfPresent(CreatorStyle.self, forKey: .creatorStyle)
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
