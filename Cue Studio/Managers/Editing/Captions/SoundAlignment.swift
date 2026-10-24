//
//  SoundAlignment.swift
//  Cue Studio
//

import Foundation

/// The heard words and script words, between two that line up, that sound alike: paired a few at a time, so a name the
/// recognizer heard as other words ("Jean Carlos disse que ela" for "Giancarlo Fisichella") pairs with it, and a word said
/// differently from the script next to it pairs with nothing. Picks the pairing that matches the most sound, weighed by how
/// alike (squared), so a long word heard right doesn't carry a different word beside it into its pair.
nonisolated enum SoundAlignment {
    /// Heard words `heard` sound like script words `written`, this much (0 to 1).
    struct Block: Equatable, Sendable {
        let heard: Range<Int>
        let written: Range<Int>
        let likeness: Double
    }

    /// Most words on each side of one pair: a name heard as several words, a compound heard in pieces.
    static let widest = (heard: 5, written: 4)
    /// Fewest letters of sound on each side: shorter words sound alike by chance.
    static let fewestSounds = 3
    /// The shorter side's sounds against the longer's, at least: a pair says about as much on both sides.
    static let lengthBalance = 0.6

    /// The pairs of `heard` and `written` at least `least` alike, in order, that match the most sound; `allows` says whether
    /// a stretch of either side may be paired at all (a number never is).
    static func blocks(
        _ heard: [String], _ written: [String], least: Double, allows: ([String]) -> Bool = { _ in true }
    ) -> [Block] {
        guard !heard.isEmpty, !written.isEmpty else { return [] }
        let heardSounds = sounds(of: heard, widest: widest.heard, allows: allows)
        let writtenSounds = sounds(of: written, widest: widest.written, allows: allows)
        // best[i][j]: the most sound matched from heard[i...] and written[j...]; step[i][j], the pair it starts with.
        var best = Array(repeating: Array(repeating: 0.0, count: written.count + 1), count: heard.count + 1)
        var step = Array(repeating: Array(repeating: Block?.none, count: written.count + 1), count: heard.count + 1)
        for i in stride(from: heard.count, through: 0, by: -1) {
            for j in stride(from: written.count, through: 0, by: -1) where i < heard.count || j < written.count {
                var score = max(i < heard.count ? best[i + 1][j] : 0, j < written.count ? best[i][j + 1] : 0)
                var chosen: Block?
                for (width, heardSound) in heardSounds[i] {
                    for (span, writtenSound) in writtenSounds[j] {
                        let shorter = Double(min(heardSound.count, writtenSound.count))
                        let longer = Double(max(heardSound.count, writtenSound.count))
                        guard Int(shorter) >= fewestSounds, shorter / longer >= lengthBalance else { continue }
                        let likeness = ScriptSpelling.ratio(heardSound, writtenSound)
                        guard likeness >= least else { continue }
                        let total = likeness * likeness * shorter + best[i + width][j + span]
                        if total > score {
                            score = total
                            chosen = Block(heard: i..<(i + width), written: j..<(j + span), likeness: likeness)
                        }
                    }
                }
                best[i][j] = score
                step[i][j] = chosen
            }
        }
        var blocks: [Block] = []
        var i = 0
        var j = 0
        while i < heard.count || j < written.count {
            if let block = step[i][j] {
                blocks.append(block)
                i = block.heard.upperBound
                j = block.written.upperBound
            } else if i < heard.count, best[i][j] == best[i + 1][j] {
                i += 1
            } else if j < written.count {
                j += 1
            } else {
                i += 1
            }
        }
        return blocks
    }

    /// For each word, the sounds of the stretches it starts that may be paired, by how many words they hold; one more than the
    /// words for the end.
    private static func sounds(of words: [String], widest: Int, allows: ([String]) -> Bool) -> [[(Int, String)]] {
        let letters = words.map(SoundKey.latinLetters)
        return (0...words.count).map { start in
            var stretches: [(Int, String)] = []
            for width in 1...max(1, widest) where start + width <= words.count {
                guard allows(Array(words[start..<(start + width)])) else { break }
                stretches.append((width, SoundKey.folded(letters[start..<(start + width)].joined())))
            }
            return stretches
        }
    }
}
