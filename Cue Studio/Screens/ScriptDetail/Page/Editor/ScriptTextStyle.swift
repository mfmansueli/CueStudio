//
//  ScriptTextStyle.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// How the script page's text view draws the words, as UIKit attributes: the words in `ink`, the AI's passage in violet until it is
/// kept, and each cue (`[pause]`) as a `TextChip`: its name semibold in yellow, the brackets clear and given the chip's insets as
/// kern, the symbol for the cue in the first one. With the Cues switch off a cue is kept but not drawn (clear and a point high, so the
/// words close up around it and editing still sees it). `ScriptTextEditor.styled` draws the same for SwiftUI (`ArrivingText`).
struct ScriptTextStyle: Equatable {
    var size: Double
    /// Where the AI's words are, in characters.
    var passage: Range<Int>?
    var showsCues: Bool

    /// The space between lines, as the page has always had it.
    static let lineSpacing: CGFloat = 6

    /// What a cue looks like in the text: "[" then at least one character up to "]", on one line (`ScriptCueDeletion.cues(in:)`).
    static let cuePattern = /\[[^\]\n]+\]/

    var chipMetrics: TextChipMetrics { TextChipMetrics(textSize: size) }

    /// The plain words, and what a new word typed anywhere takes.
    var bodyAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = Self.lineSpacing
        return [.font: UIFont.systemFont(ofSize: size), .foregroundColor: Colors.ink, .paragraphStyle: paragraph]
    }

    /// Paints `range` of `string` (whole paragraphs: a cue never crosses a line, so none is cut in half).
    func apply(to string: NSMutableAttributedString, in range: NSRange) {
        guard range.length > 0 else { return }
        string.setAttributes(bodyAttributes, range: range)
        let text = string.string
        if let passage, !passage.isEmpty {
            let painted = NSIntersectionRange(ScriptTextOffsets.nsRange(of: passage, in: text), range)
            if painted.length > 0 {
                string.addAttributes([.foregroundColor: Colors.passageInk, .backgroundColor: Colors.passageFill], range: painted)
            }
        }
        guard let bounds = Range(range, in: text) else { return }
        for match in text[bounds].matches(of: Self.cuePattern) {
            paintCue(NSRange(match.range, in: text), named: String(match.output.dropFirst().dropLast()), in: string)
        }
    }

    private func paintCue(_ cue: NSRange, named name: String, in string: NSMutableAttributedString) {
        string.removeAttribute(.backgroundColor, range: cue)
        guard showsCues else {
            string.addAttributes([.font: UIFont.systemFont(ofSize: 1), .foregroundColor: UIColor.clear], range: cue)
            return
        }
        let metrics = chipMetrics
        let symbol = ScriptCueSymbol.name(forCue: name)
        let box = TextChipBox(
            chip: TextChip(id: cue.location, symbol: symbol),
            metrics: metrics,
            fill: Colors.chipFill,
            rim: Colors.chipRim,
            ink: Colors.chipInk
        )
        string.addAttributes(
            [.font: metrics.font, .foregroundColor: Colors.chipInk, .baselineOffset: metrics.baselineOffset, TextChipAttribute.nsKey: box],
            range: cue
        )
        let opening = NSRange(location: cue.location, length: 1)
        let closing = NSRange(location: NSMaxRange(cue) - 1, length: 1)
        string.addAttributes([.foregroundColor: UIColor.clear, .kern: metrics.leadingKern(after: "[", symbol: symbol)], range: opening)
        string.addAttributes([.foregroundColor: UIColor.clear, .kern: metrics.trailingKern(after: "]")], range: closing)
    }

    /// The palette as UIKit colours, made once.
    private enum Colors {
        static let ink = UIColor(Palette.ink)
        static let passageInk = UIColor(Palette.Page.aiReplacedInk)
        static let passageFill = UIColor(Palette.Page.aiReplacedFill)
        static let chipFill = UIColor(Palette.Cues.chipFill)
        static let chipRim = UIColor(Palette.Cues.chipRim)
        static let chipInk = UIColor(Palette.Cues.chipInk)
    }
}
