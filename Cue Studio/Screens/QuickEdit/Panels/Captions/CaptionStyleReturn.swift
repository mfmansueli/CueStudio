//
//  CaptionStyleReturn.swift
//  Cue Studio
//

import Foundation

/// Where Caption style was when "Choose words to emphasize" took the creator to a line in Captions: the tab, how far it was
/// scrolled, the playhead and what was picked, so coming back (✓ or ‹ Style) finds the edit as it was left.
struct CaptionStyleReturn: Equatable {
    let tab: EditorPanelTab
    let offset: CGFloat
    let time: TimeInterval
    let selection: EditorSelection?
}
