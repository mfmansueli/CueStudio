//
//  BgWash+Presets.swift
//  Cue Studio
//

import SwiftUI

/// The lights of each background: the navigation screens and the chapters of the first flight (the boards' `.night`, one per chapter:
/// `radial-gradient(<rx> <ry> at <cx> <cy>, colour, transparent 70%)`).
extension BgWash {
    /// The board's `.neb`: a blurred ellipse of `width` × `height` pt at `left`, `top` of its 390 × 844 frame, as a soft light (it fades out a
    /// blur's width beyond the ellipse).
    static func blob(left: Double, top: Double, width: Double, height: Double, color: Color) -> Light {
        Light(
            color: color, radiusX: (width / 2 + 38) / 0.7 / 390, radiusY: (height / 2 + 38) / 0.7 / 844,
            centerX: (left + width / 2) / 390, centerY: (top + height / 2) / 844
        )
    }

    static let navigation = [
        Light(color: Palette.Aurora.bgWashViolet, radiusX: 0.7, radiusY: 0.3, centerX: 0.2, centerY: 0.06),
        Light(color: Palette.Aurora.bgWashIndigo, radiusX: 0.55, radiusY: 0.28, centerX: 0.85, centerY: 0.6),
    ]

    /// 1.1: a big violet haze over the top (where the C is) and a faint indigo one at the bottom left.
    static let welcome = [
        Light(color: Palette.Universe.nightViolet.opacity(0.30), radiusX: 0.9, radiusY: 0.45, centerX: 0.5, centerY: 0.28),
        Light(color: Palette.Settings.iconIndigo.opacity(0.16), radiusX: 0.6, radiusY: 0.3, centerX: 0.15, centerY: 0.85),
        blob(left: -70, top: 40, width: 320, height: 230, color: Palette.Universe.nightViolet.opacity(0.22)),
        blob(left: 170, top: 430, width: 300, height: 220, color: Palette.Settings.iconIndigo.opacity(0.16)),
    ]

    /// 1.2: the haze sits lower, round the core.
    static let universe = [
        Light(color: Palette.Universe.nightViolet.opacity(0.26), radiusX: 0.7, radiusY: 0.34, centerX: 0.5, centerY: 0.40),
        Light(color: Palette.Settings.iconIndigo.opacity(0.14), radiusX: 0.6, radiusY: 0.3, centerX: 0.1, centerY: 0.9),
        blob(left: -80, top: 250, width: 300, height: 220, color: Palette.Universe.nightViolet.opacity(0.18)),
        blob(left: 200, top: 120, width: 260, height: 200, color: Palette.Settings.iconIndigo.opacity(0.14)),
    ]

    /// 1.3: a cyan light where TikTok is and a violet one over the creator's galaxy.
    static let voyage = [
        Light(color: Palette.Platform.tikTok.opacity(0.12), radiusX: 0.6, radiusY: 0.3, centerX: 0.8, centerY: 0.34),
        Light(color: Palette.Universe.nightViolet.opacity(0.20), radiusX: 0.7, radiusY: 0.34, centerX: 0.3, centerY: 0.6),
        blob(left: -60, top: 380, width: 300, height: 220, color: Palette.Universe.nightViolet.opacity(0.16)),
        blob(left: 220, top: 200, width: 240, height: 200, color: Palette.Platform.tikTok.opacity(0.10)),
    ]

    /// 1.4 and 1.4b: one violet light behind the message card.
    static let message = [
        Light(color: Palette.Universe.nightViolet.opacity(0.24), radiusX: 0.8, radiusY: 0.36, centerX: 0.5, centerY: 0.46),
        blob(left: -60, top: 300, width: 280, height: 220, color: Palette.Universe.nightViolet.opacity(0.16)),
        blob(left: 220, top: 560, width: 240, height: 200, color: Palette.Settings.iconIndigo.opacity(0.14)),
    ]

    /// 1.5: a hint of yellow over the two orbs on a violet light.
    static let permissions = [
        Light(color: Palette.acc.opacity(0.08), radiusX: 0.8, radiusY: 0.32, centerX: 0.5, centerY: 0.30),
        Light(color: Palette.Universe.nightViolet.opacity(0.22), radiusX: 0.7, radiusY: 0.36, centerX: 0.5, centerY: 0.32),
        blob(left: -40, top: 120, width: 260, height: 200, color: Palette.acc.opacity(0.06)),
        blob(left: 200, top: 140, width: 240, height: 200, color: Palette.Universe.nightViolet.opacity(0.16)),
    ]

    /// 1.7: the first star's night, a little deeper than the others (`#06070D`).
    static let firstStar = [
        Light(color: Palette.Universe.nightViolet.opacity(0.3), radiusX: 0.8, radiusY: 0.4, centerX: 0.5, centerY: 0.34),
        Light(color: Palette.Settings.iconIndigo.opacity(0.16), radiusX: 0.6, radiusY: 0.3, centerX: 0.2, centerY: 0.9),
        blob(left: -60, top: 120, width: 300, height: 220, color: Palette.Universe.nightViolet.opacity(0.2)),
        blob(left: 200, top: 380, width: 240, height: 200, color: Palette.acc.opacity(0.06)),
    ]

    // MARK: - The screens of the stories (v30 `handoff-telas`: the boards' own `.night`)

    /// 9.2 Your universe: a violet haze behind the map and an indigo one on the lower right.
    static let yourUniverse = [
        Light(color: Palette.Universe.nightViolet.opacity(0.20), radiusX: 0.8, radiusY: 0.36, centerX: 0.5, centerY: 0.30),
        Light(color: Palette.Settings.iconIndigo.opacity(0.12), radiusX: 0.55, radiusY: 0.28, centerX: 0.85, centerY: 0.70),
    ]

    /// 8.2 The send-off: the haze sits to the upper right, over the planets.
    static let sendOff = [
        Light(color: Palette.Universe.nightViolet.opacity(0.26), radiusX: 0.9, radiusY: 0.4, centerX: 0.7, centerY: 0.10),
        Light(color: Palette.Settings.iconIndigo.opacity(0.16), radiusX: 0.6, radiusY: 0.3, centerX: 0.2, centerY: 0.45),
    ]

    /// 8.3 The milestone: a strong haze at the middle (`#07080E` under it, `Palette.Flight.night`).
    static let milestone = [
        Light(color: Palette.Universe.nightViolet.opacity(0.30), radiusX: 0.9, radiusY: 0.4, centerX: 0.5, centerY: 0.34),
        Light(color: Palette.Settings.iconIndigo.opacity(0.14), radiusX: 0.6, radiusY: 0.3, centerX: 0.2, centerY: 0.80),
    ]

    /// 11.4 Pro: the haze falls from the top, behind the planet that is you.
    static let pro = [
        Light(color: Palette.Universe.nightViolet.opacity(0.32), radiusX: 0.9, radiusY: 0.34, centerX: 0.5, centerY: 0.08),
        Light(color: Palette.Settings.iconIndigo.opacity(0.14), radiusX: 0.6, radiusY: 0.3, centerX: 0.8, centerY: 0.60),
    ]

    /// 8.1 Ready to travel and the networks.
    static let share = [
        Light(color: Palette.Universe.nightViolet.opacity(0.22), radiusX: 0.8, radiusY: 0.38, centerX: 0.5, centerY: 0.28),
        Light(color: Palette.Settings.iconIndigo.opacity(0.12), radiusX: 0.55, radiusY: 0.28, centerX: 0.85, centerY: 0.75),
    ]
}
