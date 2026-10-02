//
//  ParagraphFocus.swift
//  Cue Studio
//

import Foundation

/// Where the editor asks the caret to go: a paragraph and an offset in it, or nowhere (the
/// keyboard goes away). Every request has its own `token`, so asking twice for the same place is a
/// new request.
struct ParagraphFocus: Equatable {
    let index: Int?
    let offset: Int
    let token = UUID()

    static func at(_ index: Int, offset: Int) -> ParagraphFocus {
        ParagraphFocus(index: index, offset: offset)
    }

    /// Puts the keyboard away. (Not `.none`: on an optional that means nil.)
    static var keyboardAway: ParagraphFocus { ParagraphFocus(index: nil, offset: 0) }
}
