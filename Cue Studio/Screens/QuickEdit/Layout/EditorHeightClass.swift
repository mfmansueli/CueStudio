//
//  EditorHeightClass.swift
//  Cue Studio
//

import CoreGraphics

/// How much room the editor has, from the usable height (under the navigation bar, above the bottom safe area), never from
/// the iPhone's name. Each class sizes the bars, the tracks and the toolbar.
///
/// The prompt puts the regular class at 780 pt with the editor's own top bar in it; under the system's 44 pt navigation bar an
/// iPhone 16 has 715 pt and a 16 Pro 734 pt, and the prompt lists both as regular. 696 pt keeps its examples (16, 16 Pro and Pro
/// Max regular; mini compact; SE very compact). Large Dynamic Type makes a regular screen compact, like the prompt's "13/14 with
/// large Dynamic Type".
nonisolated enum EditorHeightClass: Equatable, Sendable {
    /// iPhone 16, 16 Pro, Pro Max: the prototype's layout.
    case regular
    /// mini, or a regular screen with large text: smaller tracks and toolbar labels.
    case compact
    /// iPhone SE: icon-only toolbar, full panels as sheets.
    case veryCompact

    static let regularMinimum: CGFloat = 696
    static let compactMinimum: CGFloat = 636

    init(usableHeight: CGFloat, largeText: Bool = false) {
        if usableHeight < Self.compactMinimum {
            self = .veryCompact
        } else if usableHeight < Self.regularMinimum || largeText {
            self = .compact
        } else {
            self = .regular
        }
    }

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

    /// A track under the video (photos and videos, Blur areas, texts, captions, music, voice-over): all the same height, the
    /// picked one's too, taller than they were (owner, 28/10/2026), so the current track, its items and ▾ are easy to hit; 44
    /// on a regular screen, the least a touch target should be.
    var laneHeight: CGFloat {
        switch self {
        case .regular: 44
        case .compact: 40
        case .veryCompact: 36
        }
    }

    /// A track under a panel: as tall as the video track there (owner, 28/10/2026), never taller than it is alone.
    var panelLaneHeight: CGFloat { min(laneHeight, panelMainTrackHeight) }

    /// The least a track gets while every track is out (they shrink so the video keeps half the screen; past this they
    /// scroll): the height they had before they grew.
    var openLaneMinimum: CGFloat {
        switch self {
        case .regular: 28
        case .compact: 24
        case .veryCompact: 22
        }
    }

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

    /// The narrowest a tool gets so the ones a picked item has all show whole instead of the last hiding under Delete
    /// (`EditorToolbarFit`); never under the touch target.
    var toolbarItemMinimumWidth: CGFloat {
        switch self {
        case .regular: 54
        case .compact: 50
        case .veryCompact: 46
        }
    }
}
