//
//  TimelineLaneLook.swift
//  Cue Studio
//

import CoreGraphics

/// How what sits on a track grows with it: an item's name, symbol and badge, its corners and the room around them, an empty
/// track's hint, and the gutter's icon, ▾ and the square behind the current track's. At `base` (the height tracks had before
/// they grew to 44 pt) everything is the size it was; each point taller adds a fixed share, so a 44 pt track has a 14.5 pt name
/// and a 36 pt one 13.
/// Pure (on the main actor, like `Metrics`), so the sizes are tested without a screen.
struct TimelineLaneLook: Equatable {
    /// The track height every size starts from.
    static let base: CGFloat = 28

    /// An item's name.
    let labelSize: CGFloat
    /// The symbol before an item's name.
    let symbolSize: CGFloat
    /// The dark badge over a photo's or video's frames, and a Blur area's.
    let badgeSize: CGFloat
    let badgeHeight: CGFloat
    /// An item's corners (its strip's are 2 pt rounder, so they nest).
    let radius: CGFloat
    /// Room before an item's symbol, and between the symbol and the name.
    let padding: CGFloat
    let gap: CGFloat
    /// What an empty track says.
    let hintSize: CGFloat
    /// The track's icon in the gutter, and ▾/▴ beside the current one's.
    let gutterSymbolSize: CGFloat
    let chevronSize: CGFloat
    /// The square behind the current track's icon and ▾: `chooserWidth` wide, 4 pt short of the track at each edge (never under
    /// 26, never over the track), its corners 10 at 40 tall and as much rounder or squarer as it is taller or shorter.
    let chooserHeight: CGFloat
    let chooserRadius: CGFloat

    static let chooserWidth: CGFloat = 40

    init(laneHeight: CGFloat) {
        let grown = max(0, laneHeight - Self.base)
        labelSize = Self.half(11.5 + grown * 0.175)
        symbolSize = (10 + grown * 0.25).rounded()
        badgeSize = Self.half(10.5 + grown * 0.1)
        badgeHeight = (18 + grown * 0.2).rounded()
        radius = (Metrics.laneItemRadius + grown * 0.1).rounded()
        padding = (7 + grown * 0.15).rounded()
        gap = (5 + grown * 0.1).rounded()
        hintSize = Self.half(12 + grown * 0.1)
        gutterSymbolSize = Self.half(14 + grown * 0.2)
        chevronSize = Self.half(8 + grown * 0.15)
        chooserHeight = min(laneHeight, max(26, laneHeight - 8))
        chooserRadius = min(chooserHeight / 2, (10 * chooserHeight / Self.chooserWidth).rounded())
    }

    /// To the nearest half point.
    private static func half(_ size: CGFloat) -> CGFloat {
        (size * 2).rounded() / 2
    }
}
