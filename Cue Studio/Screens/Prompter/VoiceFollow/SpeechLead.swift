//
//  SpeechLead.swift
//  Cue Studio
//

import Foundation

/// How far Voice Following's text may run ahead of the last word recognition confirmed, so it
/// moves as soon as the creator speaks instead of waiting for the recognizer, which reports words
/// in bursts a few tenths of a second behind the voice.
///
/// Recognized words stay the truth. The lead only grows while sound is coming in, at the reading
/// pace measured from the words confirmed so far; it stops the moment the voice pauses and never
/// passes `maximumWords` beyond the last confirmed word. When recognition confirms a word, the
/// lead is measured again from it: a prediction that was ahead keeps the text where it is (the
/// text never moves back), and recognition that went further takes the text with it.
nonisolated struct SpeechLead: Equatable, Sendable {
    /// The furthest the text runs ahead of the last confirmed word.
    var maximumWords: Double = 2
    /// And no more than this much of a line on screen, however short the words (applied where the
    /// words are placed, `PrompterViewModel`).
    var maximumLines: Double = 0.5
    /// Growth stops once the voice has been quiet this long: longer than the gap between two
    /// words, shorter than a pause.
    var pauseAfter: TimeInterval = 0.2
    /// Words a second the reading is taken to go at until it's measured.
    var initialRate: Double = 2.5 {
        didSet { if lastConfirmation == nil { rate = Self.clampedRate(initialRate) } }
    }

    /// Reading paces a measurement is kept within, words a second.
    static let rateRange: ClosedRange<Double> = 1.2...5
    /// Two confirmations further apart than this have a pause between them, which says nothing
    /// about the pace.
    private static let rateWindow: TimeInterval = 3

    /// The next word to read, as recognition last confirmed it.
    private(set) var confirmed = 0
    /// Words predicted past `confirmed`.
    private(set) var lead: Double = 0
    /// The reading pace, words a second.
    private(set) var rate = 2.5
    private var lastConfirmation: Confirmation?
    private var lastAdvance: TimeInterval?

    private struct Confirmation: Equatable, Sendable {
        let position: Int
        let time: TimeInterval
    }

    /// Where the text should be, in words: `confirmed` plus the lead.
    var position: Double { Double(confirmed) + lead }

    /// After a manual scroll, jump or rewind: reading picks up at `position`, with nothing
    /// predicted.
    mutating func reset(to position: Int) {
        confirmed = max(0, position)
        lead = 0
        lastConfirmation = nil
        lastAdvance = nil
    }

    /// Recognition confirmed that `position` is the next word to read.
    mutating func confirm(_ position: Int, at time: TimeInterval) {
        guard position > confirmed else { return }
        if let last = lastConfirmation, time > last.time, time - last.time < Self.rateWindow {
            let measured = Double(position - last.position) / (time - last.time)
            rate = Self.clampedRate(0.7 * rate + 0.3 * measured)
        }
        let predicted = self.position
        confirmed = position
        lead = min(maximumWords, max(0, predicted - Double(position)))
        lastConfirmation = Confirmation(position: position, time: time)
    }

    /// Moves the prediction on to `time`.
    /// - Parameter quiet: how long the voice has been quiet, nil when the creator isn't speaking.
    mutating func advance(to time: TimeInterval, quiet: TimeInterval?) {
        defer { lastAdvance = time }
        guard let last = lastAdvance, time > last, let quiet, quiet < pauseAfter else { return }
        lead = min(maximumWords, lead + rate * (time - last))
    }

    private static func clampedRate(_ rate: Double) -> Double {
        min(rateRange.upperBound, max(rateRange.lowerBound, rate))
    }
}
