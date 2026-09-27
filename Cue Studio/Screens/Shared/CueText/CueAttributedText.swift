//
//  CueAttributedText.swift
//  Cue Studio
//

import SwiftUI

/// Renders a script paragraph with its `[cues]` as small yellow tags between the words.
enum CueAttributedText {
    static func make(
        _ paragraph: String,
        showsCues: Bool = true,
        cueFont: Font,
        cueColor: Color = Palette.acc,
        cueBackground: Color = Palette.accSoft
    ) -> AttributedString {
        guard showsCues else { return AttributedString(CueParser.stripCues(paragraph)) }
        var result = AttributedString()
        for segment in CueParser.segments(in: paragraph) {
            switch segment.kind {
            case .speech:
                result += AttributedString(segment.text)
            case .cue:
                // Narrow no-break spaces pad the tag's background without ever wrapping away from it.
                var cue = AttributedString("\u{202F}\(segment.text.uppercased())\u{202F}")
                cue.font = cueFont
                cue.foregroundColor = cueColor
                cue.backgroundColor = cueBackground
                cue.kern = 1
                result += cue
            }
        }
        return result
    }
}
