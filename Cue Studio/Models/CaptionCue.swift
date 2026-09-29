//
//  CaptionCue.swift
//  Cue Studio
//

import Foundation

/// One caption line: what it says and when, in seconds of the original recording, so cuts and
/// speed changes keep it on the words it shows. It keeps its words with their own times when
/// speech recognition gave them, for word-by-word effects; a correction keeps the times it can and
/// says when the rest needs a look.
nonisolated struct CaptionCue: Codable, Hashable, Identifiable, Sendable {
    /// Shortest a line can stay on screen.
    static let minimumDuration: TimeInterval = 0.2

    var id: UUID
    var text: String
    /// Seconds in the original recording.
    var start: TimeInterval
    var end: TimeInterval
    /// Each word and when it is said; empty when only the line's own time is known.
    var words: [CaptionWord]
    var origin: CaptionOrigin
    /// The creator changed the words or the times since it was heard.
    var isRevised: Bool
    /// A correction left words whose time is a guess: the line shows, but its timing should be
    /// checked before lighting words one by one.
    var needsTimingReview: Bool

    init(
        id: UUID = UUID(), text: String, start: TimeInterval, end: TimeInterval, words: [CaptionWord] = [],
        origin: CaptionOrigin = .speech, isRevised: Bool = false, needsTimingReview: Bool = false
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = max(end, start)
        self.words = words
        self.origin = origin
        self.isRevised = isRevised
        self.needsTimingReview = needsTimingReview
    }

    /// A line from heard words, timed by them.
    init(words: [CaptionWord]) {
        self.init(
            text: CaptionText.joined(words.map(\.text)),
            start: words.first?.start ?? 0, end: words.last?.end ?? 0, words: words, origin: .speech
        )
    }

    var span: TimeSpan { TimeSpan(start: start, end: end) }

    /// Every word has a time of its own that speech recognition measured: word-by-word effects
    /// can follow the voice.
    var hasWordTiming: Bool {
        !words.isEmpty && !words.contains(where: \.isEstimated) && !needsTimingReview
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, text, start, end, words, origin, isRevised, needsTimingReview
    }

    /// Captions saved before they had an identity or words read as legacy lines.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        start = try container.decode(TimeInterval.self, forKey: .start)
        end = max(start, try container.decode(TimeInterval.self, forKey: .end))
        words = (try? container.decodeIfPresent([CaptionWord].self, forKey: .words)) ?? []
        origin = (try? container.decodeIfPresent(CaptionOrigin.self, forKey: .origin)) ?? .legacy
        isRevised = (try? container.decodeIfPresent(Bool.self, forKey: .isRevised)) ?? false
        needsTimingReview = (try? container.decodeIfPresent(Bool.self, forKey: .needsTimingReview)) ?? false
    }
}
