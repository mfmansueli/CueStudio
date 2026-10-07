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

        /// Behind the preview before the video loads.
        static let previewWell = Color(hex: 0x0E101C)

        /// The tool bar at the bottom of Quick edit.
        static let toolbarFill = Color(hex: 0x1C1C1E, opacity: 0.92)

        /// Panels under the editor's timeline.
        static let panel = Color(hex: 0x0E101C)

        /// Done and the other glass buttons of the editor's top bar.
        static let barButton = Color(hex: 0x2B2F48, opacity: 0.7)

        /// The editor's toast: one line on a dark pill.
        static let toast = Color(hex: 0x1F2236, opacity: 0.96)

        /// Separators of the toolbar and the panels.
        static let separator = Color(hex: 0x505678, opacity: 0.5)

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
    }
}
