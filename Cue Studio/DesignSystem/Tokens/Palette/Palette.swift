//
//  Palette.swift
//  Cue Studio
//

import SwiftUI

/// Semantic colors. Cue is dark only (v27 "Cue Universe"): the night is the identity, and the camera,
/// the prompter, the take review and the editor were always dark. Every token is a dark value; the
/// ones that carry information while translucent have a stronger one for Increase Contrast.
///
/// **Contrast.** Text tokens meet the Human Interface Guidelines' 4.5:1 against the surfaces they
/// sit on, and parts of controls 3:1 (`PaletteContrastTests` measures it, with `ColorContrast`).
/// Translucent text tokens (`ink2`, `ink3`) step up when Increase Contrast is on. `ink3` is for
/// what needn't be read (disclosure chevrons, dashed outlines, disabled controls), never for a
/// sentence; small hints and mono labels use `inkHint` (55% or more).
///
/// **Color roles** (enforced in review): **violet is AI** (`aiText`, `aiFill`, the aurora of the idea
/// card), **solid yellow is the one primary action or ✓ of a screen** (`acc`), **yellow text is a HUD
/// signal** (`accText`: counters, time, status), **red is recording only**, **green is ready**, **cyan is in
/// edit**. Topics are worlds (`World`) and platforms are galaxies (`Platform`): a topic is a bar (`themeRail`) in its
/// world's color, a network a dot (`platformDot`) in its galaxy's; sizes are in `Metrics`.
///
/// The core tokens below are the ones every screen uses; an area's own colors live in a namespace of their own
/// (`Palette.Editor`, `Palette.Camera`…, one file each beside this one), so a token added for one area rebuilds that
/// area's files instead of every file that uses a color.
enum Palette {
    // MARK: - Surfaces

    static let bg = Color(hex: 0x0A0B12)
    /// Cards and grouped rows.
    static let surface = Color(hex: 0x161826)
    /// Controls and rows inside a card or sheet.
    static let surface2 = Color(hex: 0x1F2236)
    /// Tiles and icons one step above `surface2` (share targets, "More").
    static let surface3 = Color(hex: 0x2B2F48)
    /// Serious formats are shown one step quieter than the rest.
    static let surfaceMuted = Color(hex: 0x1B1D2E)
    /// Inactive chips, search fields, segmented tracks, round buttons and meter tracks.
    static let fill = Color(hex: 0x6E7496, opacity: 0.26)
    /// Buttons floating over the camera and prompter.
    static let overlayFill = Color.white.opacity(0.1)
    static let separator = Color(normal: Color(hex: 0x505678, opacity: 0.5), increasedContrast: Color(hex: 0x8C92B4, opacity: 0.8))
    /// Secondary swipe actions ("More"): white text on it.
    static let neutralAction = Color(hex: 0x636366)
    /// The selected segment of a segmented control.
    static let segmentOn = Color(hex: 0x636366)
        /// A selected text chip: white with black text.
    static let chipOn = Color.white
    static let chipOnInk = Color.black
    /// Night glass: the surface of bars and floating controls (0.6–0.88 over video; see `GlassNight`).
    static let glassFill = Color(hex: 0x0E101C, opacity: 0.72)
    /// The same glass without transparency, for `GlassNight` to thin out over video.
    static let glassBase = Color(hex: 0x0E101C)
    /// Hairline around glass surfaces: the tab bar, the camera toolbar, floating buttons: a violet rim.
    static let glassBorder = Color(hex: 0xB4A7FF, opacity: 0.22)
    /// Field sunk into a tinted card, like the prompt box: a dark well.
    static let insetField = Color.black.opacity(0.38)
    /// Ring around a color swatch, so a white one is still seen on a white card.
    static let swatchRing = Color.white.opacity(0.25)

    // MARK: - Text

    static let ink = Color.white
    /// Secondary text: 4.5:1 or more on every surface.
    static let ink2 = Color(normal: Color(hex: 0xE1E4F5, opacity: 0.62), increasedContrast: Color(hex: 0xE1E4F5, opacity: 0.8))
    /// What needn't be read: chevrons, dashed outlines, rings, disabled controls. 3:1 on every
    /// surface, not enough for text.
    static let ink3 = Color(normal: Color(hex: 0xE1E4F5, opacity: 0.45), increasedContrast: Color(hex: 0xE1E4F5, opacity: 0.62))

    /// Small hints and mono labels (v27: 55% or more, about 5:1 on `bg`).
    static let inkHint = Color(
        normal: Color(hex: 0xE1E4F5, opacity: 0.55), increasedContrast: Color(hex: 0xE1E4F5, opacity: 0.72)
    )

    // MARK: - Accents

    static let acc = Color(hex: 0xFFD60A)
    /// Yellow for text and icons on the app's own surfaces (the same yellow as `acc`, kept as its own token so text and fills can part ways).
    static let accText = Color(normal: Color(hex: 0xFFD60A), increasedContrast: Color(hex: 0xFFD60A))
    /// Behind white text: the swipe action that records. `acc` is 1.4:1 under white; this is 5.3:1
    /// in either appearance.
    static let accAction = Color(hex: 0x8A6500)
    /// Text and icons on top of `acc`.
    static let accInk = Color.black
    static let accSoft = Color(hex: 0xFFD60A, opacity: 0.16)
    static let accLine = Color(hex: 0xFFD60A, opacity: 0.3)
    /// Behind AI Coach cues in the prompter: present, but quieter than the words.
    static let accCueWash = Color(hex: 0xFFD60A, opacity: 0.12)
    /// Border of the highlighted prompt card.
    static let accBorder = Color(hex: 0xFFD60A, opacity: 0.38)
    /// Yellow wash at the top of highlighted cards, fading to `accWashFaint`.
    static let accWash = Color(hex: 0xFFD60A, opacity: 0.22)
    static let accWashFaint = Color(hex: 0xFFD60A, opacity: 0.05)
    /// Pro's glow: a yellow wash from the top corner, fading into the surface.
    static let accGlow = Color(hex: 0xFFD60A, opacity: 0.14)
    static let accGlowFaint = Color(hex: 0xFFD60A, opacity: 0.02)

    // MARK: - AI (violet)

    /// Violet is the AI's color: ✦, "My Cue Voice", Smart, suggestions. Text and icons: 4.5:1 on every
    /// surface.
    static let aiText = Color(normal: Color(hex: 0xB4A7FF), increasedContrast: Color(hex: 0xCFC6FF))
    /// The stronger violet for a title or a value on an AI fill.
    static let aiTextStrong = Color(normal: Color(hex: 0xE4DEFF), increasedContrast: Color(hex: 0xF2EEFF))
    /// AI chips and tiles: the violet at 17%.
    static let aiFill = Color(hex: 0x9D8CFF, opacity: 0.17)
    /// The hairline of a highlighted AI card.
    static let aiBorder = Color(hex: 0xB4A7FF, opacity: 0.30)
    /// My Cue Voice's glow from the top corner, fading into the surface.
    static let aiGlow = Color(hex: 0x9D8CFF, opacity: 0.20)
    static let aiGlowFaint = Color(hex: 0x9D8CFF, opacity: 0.02)
    static let record = Color(hex: 0xFF3B30)
    static let danger = Color(hex: 0xFF453A)
    /// Red for text and icons on the app's own surfaces (see `accText`).
    static let dangerText = Color(normal: Color(hex: 0xFF8078), increasedContrast: Color(hex: 0xFF9A93))
    /// Behind white text: a button that removes something. `danger` is 3.4:1 under white; this is 5.4:1.
    static let dangerFill = Color(hex: 0xD70015)
    static let dangerSoft = Color(hex: 0xFF3B30, opacity: 0.2)
    static let warn = Color(hex: 0xFF9F0A)
    /// Orange for text and icons on the app's own surfaces (see `accText`).
    static let warnText = Color(normal: Color(hex: 0xFF9F0A), increasedContrast: Color(hex: 0xFFB340))
    static let warnSoft = Color(hex: 0xFF9F0A, opacity: 0.16)
    /// Fact-check warnings: a faint orange card with a hairline.
    static let warnWash = Color(hex: 0xFF9F0A, opacity: 0.08)
    static let warnBorder = Color(hex: 0xFF9F0A, opacity: 0.28)
    static let info = Color(hex: 0x64D2FF)
    /// Blue for text and icons on the app's own surfaces (see `accText`).
    static let infoText = Color(hex: 0x64D2FF)
    static let infoSoft = Color(hex: 0x64D2FF, opacity: 0.1)
    static let success = Color(hex: 0x34C759)
    /// Green for text and icons on the app's own surfaces (see `accText`).
    static let successText = Color(hex: 0x34C759)

    // MARK: - Status

    /// "Live preview" dot in Display.
    static let live = Color(hex: 0x30D158)

    // MARK: - Over the camera

    /// The warning card over the camera ("12s short of 1:00"): nearly opaque night, with a hairline.
    static let warningCard = Color(hex: 0x161826, opacity: 0.97)
    /// Keeps prompter text readable over a bright camera feed.
    static let textShadow = Color.black.opacity(0.6)
    /// Display sheet over the camera: nearly opaque, so settings stay readable, with the preview
    /// still visible above it.
    static let sheetGlass = Color(hex: 0x121422, opacity: 0.96)
}
