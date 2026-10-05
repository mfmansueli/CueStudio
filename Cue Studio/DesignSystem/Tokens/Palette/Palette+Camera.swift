//
//  Palette+Camera.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Over the camera and the prompter: the recorded frame, the safe zone, the reading line, the platform's recommendation and the REC pill.
    enum Camera {
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

        /// The "● REC" pill: a 1 pt inset ring, a 6 pt red dot (`record`) and the label in `ink`.
        static let recPillRing = Color(hex: 0xE1E4F5, opacity: 0.22)
        static let recPillDot = Palette.record
    }
}
