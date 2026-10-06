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
/// edit**. Topics are worlds (`world*`) and platforms are galaxies (`platform*`).
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
    /// The planet that is you on the Pro screen: gold lit from the top left (light, mid, shade, dark).
    static let proPlanetLight = Color(hex: 0xFFF6DC)
    static let proPlanetMid = Color(hex: 0xFFD98A)
    static let proPlanetShade = Color(hex: 0xE39A3E)
    static let proPlanetDark = Color(hex: 0x3A1E10)
    /// The cream, warm and gold of a star's light (the welcome's star, its sparks and its trail).
    static let starCream = Color(hex: 0xFFF6C2)
    /// The pale lilac of a speck of light.
    static let starLilac = Color(hex: 0xE4DEFF)
    /// The thin dark line around the core ball of YOU.
    static let coreRim = Color(hex: 0x281C00, opacity: 0.4)
    static let starWarm = Color(hex: 0xFFF0A8)
    static let starGold = Color(hex: 0xFFE680)
    /// The violet glow of the night behind a constellation.
    static let nightViolet = Color(hex: 0x9D8CFF)
    /// The night of the universe cards and the story: from this near-black at the top to the indigo at the bottom.
    static let nightDeep = Color(hex: 0x0A0B12)
    /// The card over the universe map (a planet's popover).
    static let popover = Color(hex: 0x14162A, opacity: 0.94)
    /// The sheets of the share flow and "Your video is ready": navy, a little translucent, as the board draws them.
    static let sheetNight = Color(hex: 0x14162A, opacity: 0.96)
    static let nightIndigo = Color(hex: 0x1B1740)
    /// Content cards over the sky (07 §3): translucent, so the stars show through. Solid under Reduce Transparency (`cardRowBackground()`).
    static let card = Color(hex: 0x161826, opacity: 0.64)
    /// The icon tiles of the Settings rows (the others are `record`, `acc`, `success` and `neutralAction`).
    static let iconIndigo = Color(hex: 0x5E4EE0)
    static let iconPurple = Color(hex: 0xBF5AF2)
    /// Cue Pro's tile is a deep gold with a yellow star (09 §11).
    static let iconPro = Color(hex: 0x3A2E00)
    /// The Settings rows that are not a place of their own (Restore, Terms, Acknowledgements, Version).
    static let iconNeutral = Color(hex: 0x6E7496, opacity: 0.35)
    static let iconTeal = Color(hex: 0x30B0C7)
    static let iconBlue = Color(hex: 0x0A84FF)
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
    /// The idea card (3.2 `.hero`): `#1A1840` under a violet light from the top-left and an indigo one from the bottom-right.
    static let heroBase = Color(hex: 0x1A1840)
    static let heroViolet = Color(hex: 0x9D8CFF, opacity: 0.55)
    static let heroIndigo = Color(hex: 0x5E4EE0, opacity: 0.6)
    static let heroBorder = Color(hex: 0xB4A7FF, opacity: 0.4)
    // The Scripts dock (v30, 09 §2): clean glass with two auroras, no sky inside.
    static let dockBase = Color(hex: 0x1A1840, opacity: 0.56)
    static let dockAuroraViolet = Color(hex: 0x9D8CFF, opacity: 0.36)
    static let dockAuroraIndigo = Color(hex: 0x5E4EE0, opacity: 0.40)
    static let dockRim = Color(hex: 0xC4B8FF, opacity: 0.5)
    /// The My Cue Voice tip's ✦ and the circle behind it (09 §3).
    static let tipGlyph = Color(hex: 0xC4B8FF)
    static let tipGlyphFill = Color(hex: 0x9D8CFF, opacity: 0.22)
    /// The idea's transition (09 §8): the cover over the screen, the halo around the star and the phrase under it.
    static let transitionCover = Color(hex: 0x07080E)
    static let transitionHalo = Color(hex: 0x9D8CFF, opacity: 0.34)
    static let transitionPhrase = Color(hex: 0xC4B8FF)
    static let dockField = Color(hex: 0x05060C, opacity: 0.45)
    /// A chip on the idea card (`rgba(5,6,12,0.42)`) and the voice chip's violet.
    static let heroChip = Color(hex: 0x05060C, opacity: 0.42)
    static let heroChipAI = Color(hex: 0x9D8CFF, opacity: 0.2)
    static let heroChipAIStroke = Color(hex: 0xC4B8FF, opacity: 0.4)
    /// The soft shadow that drifts across the prompt box's golden wash.
    static let insetShade = Color.black.opacity(0.38)
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
    /// Secondary text on a white (chosen-chip) fill: 5:1 or more on white, where `inkHint` would vanish.
    static let inkOnLight = Color.black.opacity(0.62)
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
    /// The avatar of the creator (9.1): a violet that goes to indigo, with a faint diagonal sheen.
    static let avatarLight = Color(hex: 0x9D8CFF)
    static let avatarDeep = Color(hex: 0x5E4EE0)
    /// Aurora behind the idea and "Sounds like you" cards: the violet and the indigo that drift across
    /// the dark surface.
    static let auroraViolet = Color(hex: 0x9D8CFF, opacity: 0.30)
    static let auroraIndigo = Color(hex: 0x5E4EE0, opacity: 0.30)
    /// The light that runs around those cards' border: lilac.
    static let auroraBorderLight = Color(hex: 0xB4A7FF)
    /// The thin yellow scan line along the bottom edge of those cards.
    static let auroraScanLine = Color(hex: 0xFFD60A)
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

    // MARK: - Platforms

    static let platformTikTok = Color(hex: 0x64D2FF)
    static let platformReels = Color(hex: 0xBF5AF2)
    static let platformShorts = Color(hex: 0xFF6B5A)
    static let platformYouTube = Color(hex: 0xFF9F0A)
    static let platformLinkedIn = Color(hex: 0x0A84FF)
    static let platformStories = Color(hex: 0xFF6FA8)
    static let platformNeutral = Color(hex: 0x8E8E93)

    // MARK: - Topics (worlds)

    /// A topic's color: up to three per creator, in this order (warm, mint, pink, sky).
    static let worldWarm = Color(hex: 0xFFC46B)
    static let worldMint = Color(hex: 0x7EE0B8)
    static let worldPink = Color(hex: 0xFF9BD2)
    static let worldSky = Color(hex: 0x8FB8FF)

    /// A world drawn as a lit sphere (1.7): the highlight, the body and the shadow side.
    static let worldPinkSphere = [Color(hex: 0xFFE6F4), worldPink, Color(hex: 0xA23F78)]
    static let worldMintSphere = [Color(hex: 0xE6FFF5), worldMint, Color(hex: 0x23735C)]
    static let worldWarmSphere = [Color(hex: 0xFFF0CC), worldWarm, Color(hex: 0xB8682A)]

    /// The ball of YOU, from its centre outwards (1.7).
    static let youCore = [Color.white, Color(hex: 0xF2EEFF), Color(hex: 0xC9BFFF)]

    /// "Live preview" dot in Display.
    static let live = Color(hex: 0x30D158)

    // MARK: - Takes

    /// The dark well a take's thumbnail sits in, at its own frame.
    static let thumbnailWell = Color(hex: 0x0E0E10)
    /// Placeholder behind a take until its poster frame loads.
    static let thumbnailTop = Color(hex: 0x7A6250)
    static let thumbnailBottom = Color(hex: 0x2A211C)
    /// The dark glass pill over a poster (a stage, "×3").
    static let posterPill = Color(hex: 0x0E101C, opacity: 0.7)
    /// Duration label over a thumbnail.
    static let durationBadge = Color.black.opacity(0.6)
    /// Tiles of the "Your takes" strip over the video.
    static let stripTile = Color(hex: 0x1F2236, opacity: 0.85)

    // MARK: - Quick edit

    /// Behind the mark on a cut (a hard cut) that picks its transition.
    static let joinMark = Color.black.opacity(0.6)
    /// Behind "Classic" captions.
    static let captionBox = Color.black.opacity(0.62)
    /// Behind the preview before the video loads.
    static let previewWell = Color(hex: 0x0E101C)
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
    /// Hairline around the Selfie script panel.
    static let panelBorder = Color.white.opacity(0.08)
    /// The platform's recommendation over the camera (smart, so violet): a gradient from the top
    /// left, a hairline rim, the icon's disc and its glyph. Its secondary lines are `aiTextStrong`.
    static let recommendationTop = Color(hex: 0x3E3096, opacity: 0.9)
    static let recommendationBottom = Color(hex: 0x1E1650, opacity: 0.9)
    static let recommendationRim = Color(hex: 0xC4B8FF, opacity: 0.45)
    static let recommendationShadow = Color(hex: 0x1E0F64, opacity: 0.5)
    static let recommendationIconFill = Color(hex: 0xC9BEFF, opacity: 0.2)
    static let recommendationIcon = Color(hex: 0xC9BEFF)
    /// The warning card over the camera ("12s short of 1:00"): nearly opaque night, with a hairline.
    static let warningCard = Color(hex: 0x161826, opacity: 0.97)
    /// Keeps prompter text readable over a bright camera feed.
    static let textShadow = Color.black.opacity(0.6)
    /// Display sheet over the camera: nearly opaque, so settings stay readable, with the preview
    /// still visible above it.
    static let sheetGlass = Color(hex: 0x121422, opacity: 0.96)

    // MARK: Editor (v10)

    /// Panels under the editor's timeline.
    static let editorPanel = Color(hex: 0x0E101C)
    /// Done and the other glass buttons of the editor's top bar.
    static let editorBarButton = Color(hex: 0x2B2F48, opacity: 0.7)
    /// The editor's toast: one line on a dark pill.
    static let editorToast = Color(hex: 0x1F2236, opacity: 0.96)
    /// Separators of the toolbar and the panels.
    static let editorSeparator = Color(hex: 0x505678, opacity: 0.5)
    /// A clip's waveform strip and its bars.
    static let waveformWell = Color(hex: 0x1A1C2C)
    static let waveformBar = Color(hex: 0xEBEBF5, opacity: 0.55)
    /// Timeline tracks: a tinted fill with the text in the full color.
    /// v26: Aa white, captions violet, music green, voice-over amber, overlay light blue.
    static let laneText = Color.white.opacity(0.2)
    static let laneTextSelected = Color.white.opacity(0.32)
    static let laneTextInk = Color.white
    static let laneCaption = Color(hex: 0x9D8CFF, opacity: 0.3)
    static let laneCaptionInk = Color(hex: 0xC9BFFF)
    static let laneMusic = Color(hex: 0x34C759, opacity: 0.3)
    static let laneMusicInk = Color(hex: 0x7CE59A)
    static let laneVoiceOver = Color(hex: 0xFF9F0A, opacity: 0.3)
    static let laneVoiceOverInk = Color(hex: 0xFFB340)
    static let laneMedia = Color(hex: 0x64D2FF, opacity: 0.3)
    static let laneMediaInk = Color(hex: 0x9FE3FF)
    /// A voice-over track while it records.
    static let laneRecording = Color(hex: 0xFF453A, opacity: 0.5)
    /// The dashed outline of "Save as my style" and "Add a line".
    static let laneGhostBorder = Color(hex: 0xEBEBF5, opacity: 0.45)
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

    // MARK: - v29

    /// Night glow of the navigation screens (`BgWash`): a violet light from the top left and an indigo
    /// one on the right, over `bg`. The same on every screen, empty states included.
    static let bgWashViolet = Color(hex: 0x9D8CFF, opacity: 0.2)
    static let bgWashIndigo = Color(hex: 0x5E4EE0, opacity: 0.12)
    /// The night under the chapters of the first flight (the boards' `.night`: `#07080E`), and the deeper one of the first star (`#06070D`).
    static let flightNight = Color(hex: 0x07080E)
    static let flightNightDeep = Color(hex: 0x06070D)

    // MARK: - Interstellar sky (Starry sky › Interstellar)

    /// Deep space under the browse screens: darker than `bg` (`#0A0B12`), so the colours of the nebulae have more night to stand out from.
    static let interstellarBg = Color(hex: 0x030409)
    /// The night glow of Interstellar (`BgWash.interstellar`): a deep indigo light from the top left, a magenta one on the right and a teal one
    /// at the bottom left. Strong enough to feel, light enough that `inkHint` still reads at the brightest point (`PaletteContrastTests`).
    static let interstellarWashIndigo = Color(hex: 0x4A3FD0, opacity: 0.20)
    static let interstellarWashMagenta = Color(hex: 0xB0408F, opacity: 0.12)
    static let interstellarWashTeal = Color(hex: 0x1F8FA8, opacity: 0.11)
    /// The nebulae's own colours (solid: each nebula carries its own peak opacity, `StarfieldMath.Nebula.opacity`).
    static let nebulaViolet = Color(hex: 0x9D8CFF)
    static let nebulaBlue = Color(hex: 0x3D5BFF)
    static let nebulaMagenta = Color(hex: 0xC2449E)
    static let nebulaTeal = Color(hex: 0x2BB3C8)
    /// The Milky Way band of Interstellar and its dust (solid; the band's peak opacity is `StarfieldMath.bandPeakOpacity`).
    static let interstellarBand = Color(hex: 0x8FA6FF)
    /// The spaceship: a faceted pale hull (light above, shaded below), deep indigo wings with a cyan edge light, ion-blue engines that leave a
    /// trail fading to violet, and two small wingtip lights. Decoration only.
    static let shipHull = Color(hex: 0xE4E9FF)
    static let shipHullShade = Color(hex: 0x8E97C9)
    static let shipWing = Color(hex: 0x3F43B0)
    static let shipEngine = Color(hex: 0x5FD4FF)
    static let shipTrailFar = Color(hex: 0x7A6CE0)
    static let shipLightPort = Color(hex: 0xFF7A8A)
    static let shipLightStarboard = Color(hex: 0x7DFFC8)

    /// The astronaut of the Adrift sky: a white suit (lit from the top left, shaded toward the bottom right), grey joints, gloves, boots and pack,
    /// and a square mirrored visor, dark with silver reflections. Decoration only (see `DESIGN_PROJECT.md` §5.0.1 on the contrast).
    static let astronautSuit = Color(hex: 0xF6F7FF)
    static let astronautSuitShade = Color(hex: 0xBCC3E0)
    static let astronautSuitDeep = Color(hex: 0x8C94B8)
    static let astronautVisorTop = Color(hex: 0x2A3170)
    static let astronautVisorBottom = Color(hex: 0x05060F)
    static let astronautSilver = Color(hex: 0xE8ECF9)
    static let astronautGlint = Color(hex: 0x9FE7FF)

    // Markers: a topic is a bar (`themeRail`, in the topic's `world*` color), a network is a dot
    // (`platformDot`, in the platform's galaxy color). Sizes are in `Metrics`.

    /// The "● REC" pill: a 1 pt inset ring, a 6 pt red dot (`record`) and the label in `ink`.
    static let recPillRing = Color(hex: 0xE1E4F5, opacity: 0.22)
    static let recPillDot = record

    // The slider: a 4 pt track, a 4 pt yellow fill and a 24 pt white thumb (`Metrics.slider*`).
    /// `#6E7496` at 35%.
    static let sliderTrack = Color(hex: 0x6E7496, opacity: 0.35)
    static let sliderFill = acc
    static let sliderThumb = Color.white
    static let sliderThumbShadow = Color.black.opacity(0.4)

    /// The AI bar over a text selection: a night violet at 97% with a 0.5 pt violet rim.
    static let selectionBar = Color(hex: 0x161434, opacity: 0.97)
    static let selectionBarRim = Color(hex: 0xB4A7FF, opacity: 0.45)
    static let selectionBarShadow = Color.black.opacity(0.5)
    /// Text the AI rewrote and the creator hasn't kept yet: `aiReplacedInk` on `aiReplacedFill`.
    static let aiReplacedInk = Color(hex: 0xE4DEFF)
    static let aiReplacedFill = Color(hex: 0x9D8CFF, opacity: 0.16)
    /// The state strip of the script page: night at 92% over a blur, with a 0.5 pt violet rim.
    static let stripFill = Color(hex: 0x0E101C, opacity: 0.92)
    static let stripRim = Color(hex: 0xB4A7FF, opacity: 0.3)

    // The state chip (READY · DRAFT · RECORDED): ink on a fill, 4.5:1 over every surface.
    static let stateReadyInk = Color(hex: 0x34C759)
    static let stateReadyFill = Color(hex: 0x34C759, opacity: 0.14)
    static let stateDraftInk = Color(hex: 0xE1E4F5, opacity: 0.8)
    static let stateDraftFill = fill
    static let stateRecordedInk = Color(hex: 0xE1E4F5, opacity: 0.85)
    static let stateRecordedFill = fill

    /// The "#AD" / "AD" tag: black on yellow.
    static let adTagFill = acc
    static let adTagInk = Color.black

    // The empty-state mark: a ring, a violet core and a star that orbits it.
    static let emptyRing = Color(hex: 0xB4A7FF, opacity: 0.22)
    static let emptyRingCore = Color(hex: 0x9D8CFF, opacity: 0.22)
    static let emptyOrbiter = Color(hex: 0xFFE680)
    static let emptyOrbiterGlow = Color(hex: 0xFFD60A, opacity: 0.7)
    /// "Your stars" in the sky above Scripts.
    static let skyStarYou = Color(hex: 0xFFE680)
    static let skyStarYouGlow = Color(hex: 0xFFD60A, opacity: 0.6)
}
