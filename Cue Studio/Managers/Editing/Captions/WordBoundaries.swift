//
//  WordBoundaries.swift
//  Cue Studio
//

import Foundation

/// Where two words that run into each other meet. In natural speech the recognizer gives such words one shared edge, in steps of
/// 60 ms, and an Edit by text cut there took a piece of the word next to it (people's voices on an iPhone: a word beside three cut
/// ones was lost in 5 of 8 readings; the system voices leave a gap between words, where it never happened). The edge moves to the
/// quietest moment within `reach` of it, where the voice dips between the two words, as an editor cuts. Words with a pause between
/// them, and estimated times, are left as they are.
nonisolated enum WordBoundaries {
    /// How far an edge may move, either way.
    static let reach: TimeInterval = 0.08
    /// Shortest a word is left.
    static let shortest: TimeInterval = 0.04
    /// Edges closer than this are one shared edge.
    static let touching: TimeInterval = 0.02
    /// How much quieter than the edge a moment has to be to move it there, in dB: a pause between words, not the closure of a
    /// consonant inside one (the "c" of "acabou" dips 9 dB, and an edge moved there cut the word's first sound).
    static let dip: Float = 12

    /// `words`, each shared edge moved to the quietest of `levels` (dBFS, one every `interval` seconds of the same recording) near it.
    static func atQuietestPoints(_ words: [TimedWord], levels: [Float], interval: TimeInterval) -> [TimedWord] {
        guard words.count > 1, !levels.isEmpty, interval > 0 else { return words }
        var result = words
        for index in 1..<result.count {
            let previous = result[index - 1]
            let next = result[index]
            guard !previous.isEstimated, !next.isEstimated, abs(next.start - previous.end) < touching else { continue }
            let edge = (previous.end + next.start) / 2
            guard let moved = quietest(near: edge, from: max(edge - reach, previous.start + shortest),
                                       to: min(edge + reach, next.end - shortest), levels: levels, interval: interval)
            else { continue }
            result[index - 1].end = moved
            result[index].start = moved
        }
        return result
    }

    /// The middle of the quietest reading whose middle lies between `lower` and `upper`, when it is `dip` quieter than the reading
    /// at `edge`; of equally quiet ones, the nearest `edge`.
    private static func quietest(
        near edge: TimeInterval, from lower: TimeInterval, to upper: TimeInterval, levels: [Float], interval: TimeInterval
    ) -> TimeInterval? {
        guard lower < upper else { return nil }
        let first = max(0, Int((lower / interval - 0.5).rounded(.up)))
        let last = min(levels.count - 1, Int((upper / interval - 0.5).rounded(.down)))
        guard first <= last else { return nil }
        let middle = { (index: Int) in (Double(index) + 0.5) * interval }
        let index = (first...last).min { lhs, rhs in
            levels[lhs] != levels[rhs] ? levels[lhs] < levels[rhs] : abs(middle(lhs) - edge) < abs(middle(rhs) - edge)
        }
        let atEdge = levels[min(levels.count - 1, max(0, Int(edge / interval)))]
        guard let index, levels[index] <= atEdge - dip else { return nil }
        return middle(index)
    }
}
