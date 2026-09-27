//
//  OCRTextLayout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Turns recognized lines back into readable paragraphs: top to bottom, lines that wrap joined with
/// a space, and a blank line where the gap between lines is clearly bigger than the line spacing.
/// Pure, so it is tested without Vision.
nonisolated enum OCRTextLayout {
    static func text(from lines: [RecognizedLine]) -> String {
        let ordered = lines
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { abs($0.box.minY - $1.box.minY) > 0.005 ? $0.box.minY < $1.box.minY : $0.box.minX < $1.box.minX }
        guard !ordered.isEmpty else { return "" }
        let heights = ordered.map(\.box.height).sorted()
        let typicalHeight = heights[heights.count / 2]

        var paragraphs: [[String]] = [[]]
        var previous: RecognizedLine?
        for line in ordered {
            if let previous {
                let gap = line.box.minY - previous.box.maxY
                if gap > typicalHeight * 0.9 { paragraphs.append([]) }
            }
            paragraphs[paragraphs.count - 1].append(line.text.trimmingCharacters(in: .whitespaces))
            previous = line
        }
        return paragraphs
            .map { joinWrapped($0) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Joins wrapped lines, keeping hyphenated words whole ("tele-" + "prompter").
    private static func joinWrapped(_ lines: [String]) -> String {
        var result = ""
        for line in lines {
            if result.isEmpty {
                result = line
            } else if result.hasSuffix("-"), let last = result.dropLast().last, last.isLetter {
                result = String(result.dropLast()) + line
            } else {
                result += " " + line
            }
        }
        return result
    }
}
