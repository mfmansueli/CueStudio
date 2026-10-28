//
//  TimelineLaneTint.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Each track in its own colour (owner, 28/10/2026): its icon in the gutter in its items' ink, the current track's icon and ▾ on
/// a square of its hue with a ring of it, and a touch of the hue on every strip, more on the current one, so a track is known
/// by its colour; a track whose tools are open lights up in it too (a ring of its hue round its strip). The amounts are
/// `Palette.Editor` tokens, measured in `PaletteContrastTests`.
enum TimelineLaneTint {
    /// The track's hue (the "add music or voice-over" shortcut takes the music's).
    static func hue(of lane: TimelineLane) -> Color {
        switch lane {
        case .main, .text: Palette.Editor.laneTextHue
        case .media: Palette.Editor.laneMediaHue
        case .blur: Palette.Editor.laneBlurHue
        case .captions: Palette.Editor.laneCaptionHue
        case .music, .audio: Palette.Editor.laneMusicHue
        case .voiceOver: Palette.Editor.laneVoiceOverHue
        }
    }

    /// The track's icon in the gutter, and ▾ beside the current one: the ink its items' names are written in.
    static func ink(of lane: TimelineLane) -> Color {
        switch lane {
        case .main, .text: Palette.Editor.laneTextInk
        case .media: Palette.Editor.laneMediaInk
        case .blur: Palette.Editor.laneBlurInk
        case .captions: Palette.Editor.laneCaptionInk
        case .music, .audio: Palette.Editor.laneMusicInk
        case .voiceOver: Palette.Editor.laneVoiceOverInk
        }
    }

    /// The square behind the current track's icon and ▾ (stronger while a finger is on it, and while its tools are open).
    static func square(of lane: TimelineLane, pressed: Bool = false) -> Color {
        hue(of: lane).opacity(pressed ? Palette.Editor.laneChooserFillPressed : Palette.Editor.laneChooserFill)
    }

    static func ring(of lane: TimelineLane) -> Color {
        hue(of: lane).opacity(Palette.Editor.laneChooserRing)
    }

    /// The track's strip: `laneStrip` with its hue laid over it.
    static func strip(of lane: TimelineLane, isCurrent: Bool) -> UIColor {
        let tint = isCurrent ? Palette.Editor.laneStripTintCurrent : Palette.Editor.laneStripTint
        return over(UIColor(Palette.Editor.laneStrip), UIColor(hue(of: lane)), by: tint)
    }

    /// The ring round the strip of a track whose tools are open.
    static func litRing(of lane: TimelineLane) -> UIColor {
        UIColor(hue(of: lane)).withAlphaComponent(Palette.Editor.laneStripRingLit)
    }

    /// The flash on the strip when an item comes in.
    static func flash(of lane: TimelineLane) -> UIColor {
        UIColor(hue(of: lane)).withAlphaComponent(Palette.Editor.laneArrivalFlash)
    }

    /// `top` at `amount` laid over the opaque `base`.
    private static func over(_ base: UIColor, _ top: UIColor, by amount: Double) -> UIColor {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (topRed, topGreen, topBlue, topAlpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        top.getRed(&topRed, green: &topGreen, blue: &topBlue, alpha: &topAlpha)
        let share = CGFloat(amount) * topAlpha
        return UIColor(
            red: red + (topRed - red) * share, green: green + (topGreen - green) * share,
            blue: blue + (topBlue - blue) * share, alpha: alpha
        )
    }
}
