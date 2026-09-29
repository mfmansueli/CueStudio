//
//  CaptionText.swift
//  Cue Studio
//

import Foundation

/// Words to caption text and back, for languages written with spaces and without (Japanese,
/// Chinese, Thai): no space is put between two words written without them.
nonisolated enum CaptionText {
    /// The words as one line.
    static func joined(_ words: [String]) -> String {
        var line = ""
        for word in words where !word.isEmpty {
            if let last = line.unicodeScalars.last, let first = word.unicodeScalars.first,
               !(WordSegmenter.isUnspaced(last) && WordSegmenter.isUnspaced(first)) {
                line += " "
            }
            line += word
        }
        return line
    }

    /// A line split into words: at spaces, and runs written without spaces into dictionary words.
    static func words(in line: String) -> [String] {
        line.split(whereSeparator: \.isWhitespace).flatMap { piece -> [String] in
            let piece = String(piece)
            guard WordSegmenter.containsUnspacedScript(piece) else { return [piece] }
            let segments = WordSegmenter.segments(of: piece).map(\.word)
            return segments.isEmpty ? [piece] : segments
        }
    }

    /// How long a line reads, in characters (spaces left out), for breaking lines evenly.
    static func length(_ words: [String]) -> Int {
        words.reduce(0) { $0 + $1.count }
    }
}
