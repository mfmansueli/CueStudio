//
//  EditorHeightClass.swift
//  Cue Studio
//

import CoreGraphics

/// How much room the editor has, from the usable height (between the real safe areas), never from
/// the iPhone's name. Each class sizes the bars, the tracks and the toolbar.
///
/// The prompt puts the regular class at 780 pt, but with the real safe areas an iPhone 16 has
/// 759 pt and a 16 Pro 778 pt, and the prompt lists both as regular. 740 pt keeps its examples
/// (16, 16 Pro and Pro Max regular; mini compact; SE very compact). Large Dynamic Type makes a
/// regular screen compact, like the prompt's "13/14 with large Dynamic Type".
nonisolated enum EditorHeightClass: Equatable, Sendable {
    /// iPhone 16, 16 Pro, Pro Max: the prototype's layout.
    case regular
    /// mini, or a regular screen with large text: smaller tracks and toolbar labels.
    case compact
    /// iPhone SE: icon-only toolbar, full panels as sheets.
    case veryCompact

    static let regularMinimum: CGFloat = 740
    static let compactMinimum: CGFloat = 680

    init(usableHeight: CGFloat, largeText: Bool = false) {
        if usableHeight < Self.compactMinimum {
            self = .veryCompact
        } else if usableHeight < Self.regularMinimum || largeText {
            self = .compact
        } else {
            self = .regular
        }
    }

    /// Done · title · Export.
    var topBarHeight: CGFloat { self == .veryCompact ? 40 : 44 }
    /// Time · play · undo, redo, full screen.
    var playerBarHeight: CGFloat { self == .veryCompact ? 40 : 44 }
    /// The video track with nothing open.
    var mainTrackHeight: CGFloat {
        switch self {
        case .regular: 56
        case .compact: 48
        case .veryCompact: 44
        }
    }

    /// The video track while a panel is open (it makes room for the panel).
    var panelMainTrackHeight: CGFloat { 40 }

    /// A track under the video (texts, captions, music, voice-over).
    var laneHeight: CGFloat {
        switch self {
        case .regular: 28
        case .compact: 24
        case .veryCompact: 22
        }
    }

    /// The track of the selected item grows so its handles are easy to hold.
    var selectedLaneHeight: CGFloat { laneHeight + 8 }

    /// Room for the time labels above the tracks.
    var rulerHeight: CGFloat { self == .regular ? 28 : 24 }

    /// Labels under the toolbar icons; the SE keeps only the icons (the label stays for VoiceOver
    /// and a long press).
    var toolbarShowsLabels: Bool { self != .veryCompact }
    var toolbarLabelSize: CGFloat { self == .regular ? 11 : 10 }
    /// Icons only on the SE, so more of them fit; still past the 44 pt touch target.
    var toolbarItemWidth: CGFloat {
        switch self {
        case .regular: 64
        case .compact: 60
        case .veryCompact: 52
        }
    }
}
