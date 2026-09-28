//
//  TakeEdit.swift
//  Cue Studio
//

import Foundation

/// Quick edit as a recipe applied on top of the original recording, which is never changed: the
/// timeline (trim, cuts, removed pieces), Clean Up's findings, audio, look, crop and captions.
/// Preview and export render the same recipe, and the take can be edited again from where it was
/// left.
nonisolated struct TakeEdit: Codable, Hashable, Sendable {
    static let volumeRange: ClosedRange<Double> = 0...1.5
    static let adjustmentRange: ClosedRange<Double> = -100...100
    static let cropOffsetRange: ClosedRange<Double> = -1...1

    // MARK: Timeline
    /// What plays: pieces of the recording, in order.
    var timeline: EditTimeline
    /// Clean Up's findings (pauses for now). Suggestions only: removing one cuts it from the
    /// timeline.
    var suggestions: [CleanUpSuggestion] = []

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
        if timeline.isWhole { untouched.timeline = timeline }
        return self != untouched
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case timeline, suggestions, volume, enhancesVoice, reducesNoise, exposure, contrast, warmth, filter
        case aspect, cropOffset, showsCaptions, captionStyle, captionPosition, captions
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
