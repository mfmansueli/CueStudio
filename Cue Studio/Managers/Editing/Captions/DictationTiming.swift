//
//  DictationTiming.swift
//  Cue Studio
//

import Foundation

/// The transcriber's words at the times dictation heard them. The transcriber writes better (punctuation, "honrar" where
/// dictation wrote "forrar"), but in people's fluent Portuguese and German it starts words a median 0.06–0.11 s after the
/// voice, up to 0.3 s, and never leaves a pause between them, so a cut by text took the first sound of the next word in every
/// reading; dictation starts them with the voice and leaves the pauses (`SpeechResultsDeviceTests`, an iPhone 15 Pro, iOS 27).
/// Each word of the transcriber's takes the time of the same word in dictation's, found in order and close in time; words the
/// two heard differently take the times of what dictation heard in their place (one by one when there are as many, as one
/// shared stretch otherwise), and a word only the transcriber heard stays where it was, inside its retimed neighbours.
nonisolated enum DictationTiming {
    /// How far apart the two may time the same word and still be taken for it.
    static let reach: TimeInterval = 0.6

    /// `transcribed` (its words and order) at `dictated`'s times.
    static func retimed(_ transcribed: [TimedWord], by dictated: [TimedWord]) -> [TimedWord] {
        let pairs = matches(transcribed, dictated)
        guard !pairs.isEmpty else { return transcribed }
        var words = transcribed
        for (heard, timed) in pairs {
            words[heard].start = dictated[timed].start
            words[heard].end = dictated[timed].end
            words[heard].isEstimated = dictated[timed].isEstimated
        }
        // The stretches between matched words: before the first, between each two, after the last.
        let anchors = [(-1, -1)] + pairs + [(transcribed.count, dictated.count)]
        for (before, after) in zip(anchors, anchors.dropFirst()) {
            let heard = Array((before.0 + 1)..<after.0)
            guard !heard.isEmpty else { continue }
            let said = Array((before.1 + 1)..<after.1)
            if said.count == heard.count {
                for (word, time) in zip(heard, said) {
                    words[word].start = dictated[time].start
                    words[word].end = dictated[time].end
                    words[word].isEstimated = dictated[time].isEstimated
                }
            } else if let first = said.first, let last = said.last {
                for word in heard {
                    words[word].start = dictated[first].start
                    words[word].end = dictated[last].end
                    words[word].isEstimated = heard.count > 1 || dictated[first].isEstimated
                }
            } else {
                let previous = before.0 >= 0 ? words[before.0] : nil
                let following = after.0 < words.count ? words[after.0] : nil
                for word in heard {
                    words[word] = inside(words[word], after: previous, before: following)
                }
            }
        }
        return words
    }

    /// `word`, which only the transcriber heard, in the room between its retimed neighbours; with no room, still after the
    /// previous one starts and before the following one ends, as not measured.
    private static func inside(_ word: TimedWord, after previous: TimedWord?, before following: TimedWord?) -> TimedWord {
        var placed = word
        let opens = previous?.end ?? -.infinity
        let closes = following?.start ?? .infinity
        placed.start = min(max(word.start, opens), closes)
        placed.end = min(max(word.end, placed.start), closes)
        guard placed.end <= placed.start else { return placed }
        placed.start = min(max(word.start, previous?.start ?? -.infinity), closes)
        placed.end = min(max(word.end, placed.start), following?.end ?? .infinity)
        placed.isEstimated = true
        return placed
    }

    /// Indices of the same word in both, in order, each pair timed within `reach`.
    private static func matches(_ transcribed: [TimedWord], _ dictated: [TimedWord]) -> [(Int, Int)] {
        let said = dictated.map { WordAlignment.key($0.text) }
        var pairs: [(Int, Int)] = []
        var next = 0
        for (index, word) in transcribed.enumerated() {
            let key = WordAlignment.key(word.text)
            guard !key.isEmpty else { continue }
            var candidate = next
            while candidate < dictated.count, dictated[candidate].start <= word.start + reach {
                if said[candidate] == key, abs(dictated[candidate].start - word.start) <= reach {
                    pairs.append((index, candidate))
                    next = candidate + 1
                    break
                }
                candidate += 1
            }
        }
        return pairs
    }
}
