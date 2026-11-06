//
//  FilterFanState.swift
//  Cue Studio
//

import CoreGraphics

/// What a screen keeps for its `FilterFan`: whether the row is open, and where it is on screen, so a touch outside it (or a scroll of the
/// list) folds it (`View.foldsFilterFan`).
nonisolated struct FilterFanState: Equatable {
    var isOpen = false
    /// The row's frame in the window, while it is open (`FilterFanPlace` keeps it the rest of the time).
    var frame: CGRect = .zero
}
