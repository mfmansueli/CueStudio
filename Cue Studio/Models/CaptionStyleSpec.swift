//
//  CaptionStyleSpec.swift
//  Cue Studio
//

import Foundation

/// Everything that makes a caption preset what it is, in one place: the font and its weight, the
/// size, the outline or shadow, the color, the plate behind the text, the spacing, how a line
/// breaks, and how it shows (its own way of lighting the words and how a line comes in). The
/// renderer reads only this, so a preset is a recipe, never only a font.
///
/// Presets have two readings (`CaptionSettings.styleVersion`). Version 1 is how the first five
/// looked, and edits saved with them keep drawing with exactly those numbers. Version 2 is the
/// complete presets: Educational and Interview, and a finer Impact, Pop and Editorial. Cue and
/// Clean are the same in both.
nonisolated struct CaptionStyleSpec: Equatable, Sendable {
    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha = 1.0

        static let white = RGB(red: 1, green: 1, blue: 1)
        static let black = RGB(red: 0, green: 0, blue: 0)
    }

    enum Plate: Equatable, Sendable {
        case none
        /// One rounded box around the whole text.
        case block(color: RGB, radius: Double, insetX: Double, insetY: Double)
        /// A rounded box behind each line.
        case perLine(color: RGB, radius: Double, insetX: Double, insetY: Double)
    }

    struct Outline: Equatable, Sendable {
        /// The stroke as a percent of the font size.
        var width: Double
        var color: RGB
    }

    struct Shadow: Equatable, Sendable {
        var opacity: Double
        var blur: Double
        var offsetY: Double
    }

    /// How a line comes in and goes out: it fades, and/or pops to size.
    struct Entry: Equatable, Sendable {
        var fade: TimeInterval = 0
        /// The size the line starts at (1 for none), growing to full with a little overshoot.
        var popScale = 1.0
        var popDuration: TimeInterval = 0

        static let none = Entry()
    }

    /// The font's registered name, and the weight asked of its `wght` axis (a font with a single
    /// cut ignores it).
    var fontName: String
    var fontWeight: Double
    /// The weight of the system font that stands in when the font lacks a glyph (a script it
    /// doesn't cover): 600 semibold, 700 bold, 800 heavy.
    var fallbackWeight: Double
    /// Points at the reference width (402), scaled with the frame.
    var baseSize: Double
    var uppercase = false
    /// Space added between letters, in points at the reference width; not used for scripts whose
    /// letters join (Arabic) or stack (Hindi, Thai), where it would break the writing.
    var tracking = 0.0
    var lineSpacing: Double
    var textColor: RGB = .white
    var outline: Outline?
    var shadow: Shadow?
    var plate: Plate = .none
    /// The widest a line may be, as a share of the frame (and never past the safe area).
    var widthFraction = 0.8
    /// A caption with more words than this is balanced over lines instead of filling the width.
    var balanceFromWords = 4
    /// How many times narrower than the full line a balanced caption is.
    var balanceRatio = 1.7
    var maxLines = 3
    /// The preset's own way of showing words (the creator can change it in Reveal).
    var animation: CaptionAnimation
    /// The word being said is boxed in the highlight color (Cue) rather than only colored.
    var highlightsWithBox = false
    var defaultAccent: CaptionAccent
    var entry = Entry.none

    // MARK: - The presets

    /// The version 2 of every preset: what a new look is made from.
    static let currentVersion = 2

    static func spec(for theme: CaptionTheme, version: Int) -> CaptionStyleSpec {
        version >= 2 ? current(theme) : original(theme)
    }

    /// How the first five looked, to the number.
    private static func original(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .cue, .educational, .interview:
            return cue
        case .impact:
            return CaptionStyleSpec(
                fontName: "Anton-Regular", fontWeight: 400, fallbackWeight: 700, baseSize: 30, uppercase: true, lineSpacing: 1,
                outline: Outline(width: 6, color: .black), animation: .highlight, defaultAccent: .lime
            )
        case .clean:
            return clean
        case .pop:
            return CaptionStyleSpec(
                fontName: "Poppins-ExtraBold", fontWeight: 800, fallbackWeight: 800, baseSize: 25, lineSpacing: 5,
                plate: .perLine(color: RGB(red: 0.39, green: 0.16, blue: 0.77), radius: 9, insetX: 10, insetY: 2),
                animation: .highlight, defaultAccent: .yellow
            )
        case .editorial:
            return CaptionStyleSpec(
                fontName: "Manrope-Regular", fontWeight: 700, fallbackWeight: 700, baseSize: 24, lineSpacing: 1,
                textColor: RGB(red: 0.96, green: 0.96, blue: 0.96),
                plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.66), radius: 5, insetX: 10, insetY: 4),
                animation: .highlight, defaultAccent: .peach
            )
        }
    }

    private static var cue: CaptionStyleSpec {
        CaptionStyleSpec(
            // Variable font's registered PostScript name; wght selects Bold.
            fontName: "SpaceGrotesk-Light", fontWeight: 700, fallbackWeight: 700, baseSize: 26, lineSpacing: 1,
            shadow: Shadow(opacity: 0.45, blur: 3, offsetY: 1), animation: .highlight, highlightsWithBox: true, defaultAccent: .yellow
        )
    }

    private static var clean: CaptionStyleSpec {
        CaptionStyleSpec(
            fontName: "Inter-Regular", fontWeight: 600, fallbackWeight: 600, baseSize: 25, lineSpacing: 1,
            shadow: Shadow(opacity: 0.45, blur: 3, offsetY: 1), animation: .line, defaultAccent: .yellow
        )
    }

    /// The complete presets.
    private static func current(_ theme: CaptionTheme) -> CaptionStyleSpec {
        switch theme {
        case .cue:
            return cue
        case .clean:
            return clean
        case .educational:
            // Clear reading: a calm sans on a soft dark plate, lines that wrap wide, and the word
            // being said in a discreet color, no box.
            return CaptionStyleSpec(
                fontName: "Manrope-Regular", fontWeight: 700, fallbackWeight: 700, baseSize: 25, lineSpacing: 3,
                plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.55), radius: 8, insetX: 12, insetY: 5),
                widthFraction: 0.84, balanceFromWords: 5, balanceRatio: 1.6, maxLines: 3,
                animation: .highlight, defaultAccent: .yellow, entry: Entry(fade: 0.12)
            )
        case .interview:
            // Sober and steady: still lines on a light scrim, medium weight, open letters and no
            // word effects; they only fade in and out.
            return CaptionStyleSpec(
                fontName: "Inter-Regular", fontWeight: 600, fallbackWeight: 600, baseSize: 23, tracking: 0.2, lineSpacing: 2,
                shadow: Shadow(opacity: 0.5, blur: 2.5, offsetY: 1),
                plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.38), radius: 4, insetX: 9, insetY: 3),
                widthFraction: 0.78, balanceFromWords: 4, balanceRatio: 1.8, maxLines: 2,
                animation: .line, defaultAccent: .white, entry: Entry(fade: 0.1)
            )
        case .impact:
            // Strong: condensed capitals with a thick black outline and a shadow under it, short
            // lines (two at most), and a quick punch in.
            return CaptionStyleSpec(
                fontName: "Anton-Regular", fontWeight: 400, fallbackWeight: 700, baseSize: 30, uppercase: true, lineSpacing: 1,
                outline: Outline(width: 7, color: .black), shadow: Shadow(opacity: 0.55, blur: 4, offsetY: 2),
                widthFraction: 0.72, balanceFromWords: 3, balanceRatio: 1.5, maxLines: 2,
                animation: .highlight, defaultAccent: .lime, entry: Entry(popScale: 0.9, popDuration: 0.1)
            )
        case .pop:
            // Expressive: heavy rounded type on a bold violet plate behind each line, and a bouncy entry.
            return CaptionStyleSpec(
                fontName: "Poppins-ExtraBold", fontWeight: 800, fallbackWeight: 800, baseSize: 25, lineSpacing: 6,
                plate: .perLine(color: RGB(red: 0.39, green: 0.16, blue: 0.77), radius: 10, insetX: 11, insetY: 3),
                animation: .highlight, defaultAccent: .yellow, entry: Entry(popScale: 0.86, popDuration: 0.18)
            )
        case .editorial:
            // Elegant: a display serif with open spacing and generous leading on a soft plate, and a slow fade.
            return CaptionStyleSpec(
                fontName: "DMSerifDisplay-Regular", fontWeight: 400, fallbackWeight: 700, baseSize: 25, tracking: 0.6, lineSpacing: 4,
                textColor: RGB(red: 0.96, green: 0.96, blue: 0.96),
                plate: .block(color: RGB(red: 0, green: 0, blue: 0, alpha: 0.55), radius: 4, insetX: 14, insetY: 6),
                widthFraction: 0.78, animation: .highlight, defaultAccent: .peach, entry: Entry(fade: 0.2)
            )
        }
    }
}
