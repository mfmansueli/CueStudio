//
//  Palette.swift
//  Cue Studio
//

import SwiftUI

/// Semantic colors. Cue runs in dark appearance (a camera app should not flash white), but every
/// token keeps a light value so the app stays correct if the appearance lock is ever removed.
enum Palette {
    // MARK: - Surfaces

    static let bg = Color(light: Color(hex: 0xF2F2F7), dark: .black)
    /// Cards and grouped rows.
    static let surface = Color(light: .white, dark: Color(hex: 0x1C1C1E))
    /// Controls and rows inside a card or sheet.
    static let surface2 = Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x2C2C2E))
    /// Tiles and icons one step above `surface2` (share targets, "More").
    static let surface3 = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x3A3A3C))
    /// Serious formats are shown one step quieter than the rest.
    static let surfaceMuted = Color(light: Color(hex: 0xEDEDF0), dark: Color(hex: 0x242426))
    /// Inactive chips, search fields and meter tracks.
    static let fill = Color(light: Color(hex: 0x767680, opacity: 0.12), dark: Color(hex: 0x767680, opacity: 0.24))
    /// Buttons floating over the camera and prompter.
    static let overlayFill = Color.white.opacity(0.1)
    static let separator = Color(light: Color(hex: 0x3C3C43, opacity: 0.29), dark: Color(hex: 0x545458, opacity: 0.6))
    /// Secondary swipe actions ("More") and the selected segment of a segmented control.
    static let neutralAction = Color(hex: 0x636366)
    /// Hairline around glass surfaces: the tab bar, the camera toolbar, floating buttons.
    static let glassBorder = Color.white.opacity(0.12)
    /// Field sunk into a tinted card, like the prompt box.
    static let insetField = Color.black.opacity(0.38)

    // MARK: - Text

    static let ink = Color(light: .black, dark: .white)
    static let ink2 = Color(light: Color(hex: 0x3C3C43, opacity: 0.6), dark: Color(hex: 0xEBEBF5, opacity: 0.6))
    static let ink3 = Color(light: Color(hex: 0x3C3C43, opacity: 0.3), dark: Color(hex: 0xEBEBF5, opacity: 0.3))

    // MARK: - Accents

    static let acc = Color(light: Color(hex: 0xFFCC00), dark: Color(hex: 0xFFD60A))
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
    /// Creator Voice and Pro cards: a yellow glow from the top corner, fading into the surface.
    static let accGlow = Color(hex: 0xFFD60A, opacity: 0.14)
    static let accGlowFaint = Color(hex: 0xFFD60A, opacity: 0.02)
    static let record = Color(hex: 0xFF3B30)
    static let danger = Color(light: Color(hex: 0xFF3B30), dark: Color(hex: 0xFF453A))
    static let dangerSoft = Color(hex: 0xFF3B30, opacity: 0.2)
    static let warn = Color(light: Color(hex: 0xFF9500), dark: Color(hex: 0xFF9F0A))
    static let warnSoft = Color(hex: 0xFF9F0A, opacity: 0.16)
    /// Fact-check warnings: a faint orange card with a hairline.
    static let warnWash = Color(hex: 0xFF9F0A, opacity: 0.08)
    static let warnBorder = Color(hex: 0xFF9F0A, opacity: 0.28)
    static let info = Color(light: Color(hex: 0x32ADE6), dark: Color(hex: 0x64D2FF))
    static let infoSoft = Color(hex: 0x64D2FF, opacity: 0.1)
    static let success = Color(hex: 0x34C759)

    // MARK: - Platforms

    static let platformTikTok = Color(hex: 0x64D2FF)
    static let platformReels = Color(hex: 0xBF5AF2)
    static let platformShorts = Color(hex: 0xFF6961)
    static let platformYouTube = Color(hex: 0xFF9F0A)
    static let platformLinkedIn = Color(hex: 0x0A84FF)
    static let platformStories = Color(hex: 0xFF375F)
    static let platformNeutral = Color(hex: 0x8E8E93)

    /// "Live preview" dot in Display.
    static let live = Color(hex: 0x30D158)

    // MARK: - Takes

    /// The dark well a take's thumbnail sits in, at its own frame.
    static let thumbnailWell = Color(hex: 0x0E0E10)
    /// Placeholder behind a take until its poster frame loads.
    static let thumbnailTop = Color(hex: 0x7A6250)
    static let thumbnailBottom = Color(hex: 0x2A211C)
    /// Duration label over a thumbnail.
    static let durationBadge = Color.black.opacity(0.6)
    /// Tiles of the "Your takes" strip over the video.
    static let stripTile = Color(hex: 0x2C2C2E, opacity: 0.85)

    // MARK: - Editor

    /// The tools panel above the keyboard.
    static let toolsPanel = Color(hex: 0x0E0E10)

    // MARK: - Quick edit

    /// Inside the red "Remove part" range.
    static let removalFill = Color(hex: 0xFF453A, opacity: 0.3)
    /// A selected section on the timeline.
    static let selectedSectionFill = Color.white.opacity(0.14)
    /// What a trim handle is about to cut, while it's dragged.
    static let trimDim = Color.black.opacity(0.72)
    /// Hairline around the time bubble above the timeline.
    static let bubbleBorder = Color.white.opacity(0.25)
    /// The tick at the start of each frame, when the timeline is zoomed in to frame precision.
    static let frameTick = Color.white.opacity(0.7)
    /// The thin line where one section cuts to the next on the timeline.
    static let cutLine = Color.white.opacity(0.55)
    /// Behind the mark on a cut (a hard cut) that picks its transition.
    static let joinMark = Color.black.opacity(0.6)
    /// Behind "Classic" captions.
    static let captionBox = Color.black.opacity(0.62)
    /// Behind the preview before the video loads.
    static let previewWell = Color(hex: 0x111113)
    /// The tool bar at the bottom of Quick edit.
    static let toolbarFill = Color(hex: 0x1C1C1E, opacity: 0.92)

    // MARK: - Camera

    /// Darkens the screen outside the recorded frame.
    static let frameMask = Color.black.opacity(0.6)
    /// Hairlines at the edges of the recorded frame.
    static let frameEdge = Color.white.opacity(0.22)
    static let gridLine = Color.white.opacity(0.28)
    /// Safe zone: dashed outline of the clear area and its caption.
    static let safeZoneLine = Color.white.opacity(0.4)
    static let safeZoneLabel = Color.white.opacity(0.62)
    /// Safe zone shading, top and bottom (fading inward) and at the sides.
    static let safeZoneShade = Color.black.opacity(0.4)
    static let safeZoneShadeFaint = Color.black.opacity(0.1)
    static let safeZoneSide = Color.black.opacity(0.16)
    /// Soft glow around the Selfie reading line.
    static let readingLineGlow = Color(hex: 0xFFD60A, opacity: 0.45)
    /// Reading line handle, at rest and while dragged.
    static let readingLineHandle = Color(hex: 0x1E1E20, opacity: 0.55)
    static let readingLineHandleActive = Color(hex: 0xFFD60A, opacity: 0.55)
    static let readingLineHandleBorder = Color.white.opacity(0.28)
    /// The stop button left on screen while the controls are hidden.
    static let stopButtonRing = Color.white.opacity(0.85)
    static let stopButtonFill = Color.black.opacity(0.18)
    /// Hairline around the Selfie script panel.
    static let panelBorder = Color.white.opacity(0.08)
    /// Keeps prompter text readable over a bright camera feed.
    static let textShadow = Color.black.opacity(0.6)
    /// Display sheet over the camera: nearly opaque, so settings stay readable, with the preview
    /// still visible above it.
    static let sheetGlass = Color(hex: 0x1C1C1E, opacity: 0.97)
}
