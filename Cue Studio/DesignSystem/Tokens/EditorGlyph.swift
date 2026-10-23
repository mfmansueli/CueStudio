//
//  EditorGlyph.swift
//  Cue Studio
//

import SwiftUI

/// The sizes the editor draws its symbols at, smallest first. Fixed on purpose: a tool's icon never outgrows its button while
/// the words beside it grow with the text size. A new size is a new step here, never a number in a view (SwiftLint
/// `editor_loose_font_size`).
enum EditorGlyph {
    /// The badge on a tool ("PRO", a count).
    static let badge: CGFloat = 8.5
    /// A mark inside a pill (a toast's star, a pause sign).
    static let mark: CGFloat = 10
    /// A sign beside words or on a handle (arrows, a compare or listen sign).
    static let small: CGFloat = 11
    /// The icon of a chip or a small row.
    static let chip: CGFloat = 12
    static let compact: CGFloat = 13
    /// The icon of a row's button.
    static let row: CGFloat = 14
    /// A panel button's icon.
    static let button: CGFloat = 15
    static let tile: CGFloat = 16
    /// A control in a panel's header or a sheet.
    static let control: CGFloat = 17
    /// A tile's icon.
    static let tool: CGFloat = 18
    /// The toolbar's icons.
    static let toolbar: CGFloat = 19
    static let large: CGFloat = 20
    /// The toolbar's add button.
    static let add: CGFloat = 21
    /// The player's controls and the large glyphs.
    static let player: CGFloat = 22
}

extension Font {
    /// A symbol (or a mark) drawn at one of the editor's glyph sizes (`EditorGlyph`).
    static func editorGlyph(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}
