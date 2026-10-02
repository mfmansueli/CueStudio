//
//  Palette.swift
//  Cue Studio
//

import SwiftUI

/// Semantic colors. Cue runs in dark appearance (a camera app should not flash white), but every
/// token keeps a light value so the app stays correct if the appearance lock is ever removed.
///
/// **Contrast.** Text tokens meet the Human Interface Guidelines' 4.5:1 against the surfaces they
/// sit on, in both appearances, and parts of controls 3:1 (`PaletteContrastTests` measures it, with
/// `ColorContrast`). That is why yellow, orange, red, blue and green each have a second token for
/// text and icons (`accText`, `warnText`, `dangerText`, `infoText`, `successText`): the bright
/// ones are fills, and on white they disappear. Translucent text tokens (`ink2`, `ink3`) step up
/// when Increase Contrast is on. `ink3` is for what needn't be read (disclosure chevrons, dashed
/// outlines, disabled controls), never for a sentence.
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
    static let separator = Color(
        light: Color(hex: 0x3C3C43, opacity: 0.29), dark: Color(hex: 0x545458, opacity: 0.6),
        lightIncreasedContrast: Color(hex: 0x3C3C43, opacity: 0.6), darkIncreasedContrast: Color(hex: 0x8E8E93, opacity: 0.8)
    )
    /// Secondary swipe actions ("More") and the selected segment of a segmented control.
    static let neutralAction = Color(hex: 0x636366)
    /// Hairline around glass surfaces: the tab bar, the camera toolbar, floating buttons.
    static let glassBorder = Color.white.opacity(0.12)
    /// Field sunk into a tinted card, like the prompt box.
    static let insetField = Color.black.opacity(0.38)

    // MARK: - Text

    static let ink = Color(light: .black, dark: .white)
    /// Secondary text: 4.5:1 or more on every surface. In light it is opaque, since a translucent
    /// gray measures worse on the darker surfaces.
    static let ink2 = Color(
        light: Color(hex: 0x55555A), dark: Color(hex: 0xEBEBF5, opacity: 0.6),
        lightIncreasedContrast: Color(hex: 0x3C3C43), darkIncreasedContrast: Color(hex: 0xEBEBF5, opacity: 0.78)
    )
    /// What needn't be read: chevrons, dashed outlines, rings, disabled controls. 3:1 on every
    /// surface, not enough for text.
    static let ink3 = Color(
        light: Color(hex: 0x6E6E73), dark: Color(hex: 0xEBEBF5, opacity: 0.45),
        lightIncreasedContrast: Color(hex: 0x4F4F54), darkIncreasedContrast: Color(hex: 0xEBEBF5, opacity: 0.62)
    )

    // MARK: - Accents

    static let acc = Color(light: Color(hex: 0xFFCC00), dark: Color(hex: 0xFFD60A))
    /// Yellow for text and icons on the app's own surfaces. `acc` is a fill: as text it is 12:1 on
    /// the dark surfaces but 1.5:1 on the light ones, so in the light appearance this is a dark gold.
    static let accText = Color(
        light: Color(hex: 0x7A5C00), dark: Color(hex: 0xFFD60A),
        lightIncreasedContrast: Color(hex: 0x5E4700), darkIncreasedContrast: Color(hex: 0xFFD60A)
    )
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
    /// Red for text and icons on the app's own surfaces (see `accText`).
    static let dangerText = Color(
        light: Color(hex: 0xA8001A), dark: Color(hex: 0xFF8078),
        lightIncreasedContrast: Color(hex: 0x9C0010), darkIncreasedContrast: Color(hex: 0xFF9A93)
    )
    /// Behind white text: a button that removes something. `danger` is 3.4:1 under white; this is 5.4:1.
    static let dangerFill = Color(hex: 0xD70015)
    static let dangerSoft = Color(hex: 0xFF3B30, opacity: 0.2)
    static let warn = Color(light: Color(hex: 0xFF9500), dark: Color(hex: 0xFF9F0A))
    /// Orange for text and icons on the app's own surfaces (see `accText`).
    static let warnText = Color(
        light: Color(hex: 0x9A4A00), dark: Color(hex: 0xFF9F0A),
        lightIncreasedContrast: Color(hex: 0x7A3A00), darkIncreasedContrast: Color(hex: 0xFFB340)
    )
    static let warnSoft = Color(hex: 0xFF9F0A, opacity: 0.16)
    /// Fact-check warnings: a faint orange card with a hairline.
    static let warnWash = Color(hex: 0xFF9F0A, opacity: 0.08)
    static let warnBorder = Color(hex: 0xFF9F0A, opacity: 0.28)
    static let info = Color(light: Color(hex: 0x32ADE6), dark: Color(hex: 0x64D2FF))
    /// Blue for text and icons on the app's own surfaces (see `accText`).
    static let infoText = Color(light: Color(hex: 0x00638F), dark: Color(hex: 0x64D2FF))
    static let infoSoft = Color(hex: 0x64D2FF, opacity: 0.1)
    static let success = Color(hex: 0x34C759)
    /// Green for text and icons on the app's own surfaces (see `accText`).
    static let successText = Color(light: Color(hex: 0x1A6F2E), dark: Color(hex: 0x34C759))

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

    // MARK: - Quick edit

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

    // MARK: Editor (v10)

    /// Panels under the editor's timeline.
    static let editorPanel = Color(hex: 0x121214)
    /// Done and the other glass buttons of the editor's top bar.
    static let editorBarButton = Color(hex: 0x3A3A3C, opacity: 0.7)
    /// The editor's toast: one line on a dark pill.
    static let editorToast = Color(hex: 0x2C2C2E, opacity: 0.96)
    /// Separators of the toolbar and the panels.
    static let editorSeparator = Color(hex: 0x545458, opacity: 0.5)
    /// A clip's waveform strip and its bars.
    static let waveformWell = Color(hex: 0x232326)
    static let waveformBar = Color(hex: 0xEBEBF5, opacity: 0.55)
    /// Timeline tracks: a tinted fill with the text in the full color.
    static let laneText = Color(hex: 0xFFD60A, opacity: 0.2)
    static let laneTextSelected = Color(hex: 0xFFD60A, opacity: 0.32)
    static let laneCaption = Color(hex: 0xEBEBF5, opacity: 0.14)
    static let laneMusic = Color(hex: 0x0A84FF, opacity: 0.3)
    static let laneMusicInk = Color(hex: 0x64D2FF)
    static let laneVoiceOver = Color(hex: 0xFF9F0A, opacity: 0.3)
    static let laneVoiceOverInk = Color(hex: 0xFFB340)
    static let laneMedia = Color(hex: 0xBF5AF2, opacity: 0.3)
    static let laneMediaInk = Color(hex: 0xDA8FFF)
    /// A voice-over track while it records.
    static let laneRecording = Color(hex: 0xFF453A, opacity: 0.5)
    /// The dashed outline of "Save as my style" and "Add a line".
    static let laneGhostBorder = Color(hex: 0xEBEBF5, opacity: 0.3)
    /// The strip each track sits on, and the same strip while its tools are open (with its ring).
    static let laneStrip = Color(hex: 0x1C1C1E)
    static let laneStripActive = Color(hex: 0x24231C)
    static let laneStripRing = Color(hex: 0xFFD60A, opacity: 0.75)
    /// A track's icon in the gutter beside its strip.
    static let laneGutterInk = Color(hex: 0xEBEBF5, opacity: 0.85)
    /// "Tap to add text" and the other hints on an empty track. The prototype draws them at 45%,
    /// which is 3.9:1 on the strip; 60% is 5.9:1, past the 4.5:1 text needs.
    static let laneHintInk = Color(hex: 0xEBEBF5, opacity: 0.6)
    /// Pauses on the video track: marked to go (yellow hatch) or kept (gray hatch).
    static let pauseRemoveStripe = Color(hex: 0xFFD60A, opacity: 0.62)
    static let pauseRemoveGap = Color(hex: 0xFFD60A, opacity: 0.2)
    static let pauseKeepStripe = Color.white.opacity(0.25)
    static let pauseKeepGap = Color.black.opacity(0.3)
    static let pauseKeepBorder = Color.white.opacity(0.75)
    /// Ruler labels and ticks.
    static let rulerLabel = Color(hex: 0xEBEBF5, opacity: 0.55)
    /// A selected card's wash (pauses to remove, a Zoom or Crop tile).
    static let accTile = Color(hex: 0xFFD60A, opacity: 0.12)
    /// The row of a list the caret or the choice is in (Sections).
    static let selectedRow = Color(hex: 0xFFD60A, opacity: 0.08)
    /// A pause card to remove.
    static let accCard = Color(hex: 0xFFD60A, opacity: 0.1)
    /// Cards and rows inside panels.
    static let panelCard = Color(hex: 0x767680, opacity: 0.16)
    /// The slider's track.
    static let sliderTrack = Color(hex: 0x767680, opacity: 0.4)
    /// The ring of an Adjust dial that is still at zero.
    static let adjustDialRing = Color(hex: 0xEBEBF5, opacity: 0.35)
    /// A switch that is off.
    static let toggleOff = Color(hex: 0x787880, opacity: 0.36)
    /// A small delete button inside a panel (a caption line's trash).
    static let dangerWash = Color(hex: 0xFF453A, opacity: 0.16)
    /// The frame picked on Cover's strip: everything else dimmed.
    static let coverDim = Color.black.opacity(0.5)
    /// A preset card: the frame of the take under the sample, darkened, and the card's edge.
    static let presetCardDim = Color.black.opacity(0.28)
    static let presetCardBorder = Color.white.opacity(0.08)
}
