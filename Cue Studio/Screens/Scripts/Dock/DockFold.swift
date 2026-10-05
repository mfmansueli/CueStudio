//
//  DockFold.swift
//  Cue Studio
//

import CoreGraphics

/// When the dock's first row folds away (09 §6): the list scrolls down past 40 pt (moving more than 2 pt), and it comes back on any
/// upward movement of more than 2 pt, or when the list is back within 40 pt of the top. Never while the field has the focus.
nonisolated struct DockFold: Equatable {
    /// How far the list has to be scrolled before the row may fold.
    static let threshold: CGFloat = 40
    /// How much the list has to move to count as a direction.
    static let slop: CGFloat = 2

    private(set) var isFolded = false
    private var lastOffset: CGFloat = 0

    /// Reads a new scroll offset (0 at the top, growing downwards) and says whether the row is folded.
    @discardableResult
    mutating func update(offset: CGFloat, isEditing: Bool) -> Bool {
        defer { lastOffset = offset }
        if isEditing {
            isFolded = false
        } else if offset > Self.threshold, offset > lastOffset + Self.slop {
            isFolded = true
        } else if offset < lastOffset - Self.slop || offset < Self.threshold {
            isFolded = false
        }
        return isFolded
    }
}
