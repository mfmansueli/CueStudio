//
//  ScriptDirection.swift
//  Cue Studio
//

import Foundation

/// Which way a script's text runs, so an Arabic script reads right to left in the prompter even
/// when Cue's interface is in English. Pure: it looks at the letters, not at any setting.
nonisolated enum ScriptDirection {
    /// Letters looked at; the start of a script is enough to tell.
    private static let sample = 600

    /// True when most letters are from a right-to-left alphabet (Arabic, Hebrew and their kin).
    static func isRightToLeft(_ text: String) -> Bool {
        var rightToLeft = 0
        var leftToRight = 0
        for scalar in text.unicodeScalars.prefix(sample * 2) where scalar.properties.isAlphabetic {
            if isRightToLeftScalar(scalar) { rightToLeft += 1 } else { leftToRight += 1 }
            if rightToLeft + leftToRight >= sample { break }
        }
        return rightToLeft > leftToRight
    }

    /// The script's direction: its language when set, otherwise its letters.
    static func isRightToLeft(_ script: Script) -> Bool {
        script.language?.isRightToLeft ?? isRightToLeft(script.text)
    }

    private static func isRightToLeftScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF: true // Hebrew, Arabic, Syriac, Thaana…
        default: false
        }
    }
}
