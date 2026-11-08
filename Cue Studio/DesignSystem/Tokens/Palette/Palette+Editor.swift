//
//  Palette+Editor.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Quick edit and the editor (v10): the preview, the timeline's tracks, panels and cards.
    enum Editor {
        /// Behind the mark on a cut (a hard cut) that picks its transition.
        static let joinMark = Color.black.opacity(0.6)

        /// Behind "Classic" captions.
        static let captionBox = Color.black.opacity(0.62)

        /// The dashed outline of a photo or video on the preview that isn't picked: white over a dark halo
        /// (`overlayOutlineHalo`), so it reads on any picture, light or dark (WCAG 1.4.11).
        static let overlayOutline = Color.white
        static let overlayOutlineHalo = Color.black.opacity(0.75)

        /// The safe zone guide over the preview (`SafeGuideOverlay`): the edge of the part an app leaves clear, white over a dark
        /// halo so it reads on any picture, light or dark (a line that informs, 3:1); the parts its buttons cover, shaded a little
        /// (only a hint: the line carries it); and the guide's label, `ink` on its own dark plate, which reads at 4.5:1 over a white
        /// frame, shaded or not (`PaletteContrastTests.theSafeGuideReadsOverAnyPicture`).
        static let safeGuideLine = Color.white
        static let safeGuideHalo = Color.black.opacity(0.75)
        static let safeGuideShade = Color.black.opacity(0.3)
        static let safeGuidePlate = Color.black.opacity(0.72)

        /// Cover Studio's crop guide: the part a profile grid hides, shaded, and the guide's label (white on it reads on any
        /// picture: the shade and the label's own dark pill).
        static let cropShade = Color.black.opacity(0.45)
        static let cropLabel = Color.black.opacity(0.72)

        /// Behind the script shown over the preview while a voice-over records: dark enough that every prompter text colour
        /// reads at 4.5:1 or more even over a white frame (`PaletteContrastTests.theNarrationScriptReadsOverAnyPicture`).
        static let narrationScrim = Color.black.opacity(0.72)

        /// Behind the preview before the video loads.
        static let previewWell = Color(hex: 0x0E101C)

        /// The tool bar at the bottom of Quick edit.
        static let toolbarFill = Color(hex: 0x1C1C1E, opacity: 0.92)

        /// Panels under the editor's timeline.
        static let panel = Color(hex: 0x0E101C)

        /// Done and the other glass buttons of the editor's top bar.
        static let barButton = Color(hex: 0x2B2F48, opacity: 0.7)

        /// Separators of the toolbar and the panels.
        static let separator = Color(hex: 0x505678, opacity: 0.5)

        /// A clip's waveform strip and its bars.
        static let waveformWell = Color(hex: 0x1A1C2C)
        static let waveformBar = Color(hex: 0xEBEBF5, opacity: 0.55)

        /// Timeline tracks: a tinted fill with the text in the full color.
        /// v26: Aa white, captions violet, music green, voice-over amber, overlay light blue.
        static let laneText = Color.white.opacity(0.2)
        /// 28%: white text keeps 4.5:1 on it over the current Texts strip, tinted white as it is.
        static let laneTextSelected = Color.white.opacity(0.28)
        static let laneTextInk = Color.white
        static let laneCaption = Color(hex: 0x9D8CFF, opacity: 0.3)
        static let laneCaptionInk = Color(hex: 0xC9BFFF)
        static let laneMusic = Color(hex: 0x34C759, opacity: 0.3)
        static let laneMusicInk = Color(hex: 0x7CE59A)
        static let laneVoiceOver = Color(hex: 0xFF9F0A, opacity: 0.3)
        /// Light enough to keep 4.5:1 on its fill over the current track's strip, the amber it is tinted with included.
        static let laneVoiceOverInk = Color(hex: 0xFFC46B)
        static let laneMedia = Color(hex: 0x64D2FF, opacity: 0.3)
        static let laneMediaInk = Color(hex: 0x9FE3FF)
        /// Blur areas: slate, so the orange of what's left unchecked stands out on them.
        static let laneBlur = Color(hex: 0x9A9AB8, opacity: 0.32)
        static let laneBlurInk = Color(hex: 0xDCDCEE)
        /// What's left unchecked on a Blur area's bar: orange hatch, the warning's color.
        static let blurUncheckedStripe = Color(hex: 0xFF9F0A, opacity: 0.9)
        static let blurUncheckedGap = Color(hex: 0xFF9F0A, opacity: 0.25)

        /// A voice-over track while it records.
        static let laneRecording = Color(hex: 0xFF453A, opacity: 0.5)

        /// The dashed outline of "Save as my style" and "Add a line".
        static let laneGhostBorder = Color(hex: 0xEBEBF5, opacity: 0.45)

        /// The strip each track sits on.
        static let laneStrip = Color(hex: 0x1C1C1E)

        /// Each track's own colour (owner, 28/10/2026): the square behind the current track's icon and ▾, its ring, and a
        /// touch of it on every strip; its icon in the gutter is in its items' ink (`TimelineLaneTint`). The same hues as the
        /// items' fills.
        static let laneTextHue = Color.white
        static let laneCaptionHue = Color(hex: 0x9D8CFF)
        static let laneMusicHue = Color(hex: 0x34C759)
        static let laneVoiceOverHue = Color(hex: 0xFF9F0A)
        static let laneMediaHue = Color(hex: 0x64D2FF)
        static let laneBlurHue = Color(hex: 0x9A9AB8)
        /// How much of its hue the current track's square takes (more while a finger is on it), and its 1 pt ring.
        static let laneChooserFill: Double = 0.22
        static let laneChooserFillPressed: Double = 0.34
        static let laneChooserRing: Double = 0.5
        /// How much of its hue a strip takes over `laneStrip`: the current track's twice as much.
        static let laneStripTint: Double = 0.06
        static let laneStripTintCurrent: Double = 0.12
        /// The flash on a track's strip when an item comes in.
        static let laneArrivalFlash: Double = 0.3
        /// A track whose tools are open lights up in its own colour (owner, 28/10/2026): its strip tinted as the current
        /// one's, a 1.5 pt ring of its hue at this much (3:1 against the strip, WCAG 1.4.11), and its square as when pressed.
        /// The strip itself can't take more of the hue: an empty track's hint must keep 4.5:1 on it.
        static let laneStripRingLit: Double = 0.85

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
        /// Behind a preset card's marks (★, "Default"): dark enough for `chipOn` words and symbols on any frame of the take.
        static let presetCardBadge = Color.black.opacity(0.66)
    }
}
