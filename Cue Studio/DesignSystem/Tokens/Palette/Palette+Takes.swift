//
//  Palette+Takes.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Takes: thumbnails, posters and the badges over them, and the pipeline (6.2).
    enum Takes {
        /// The "shared" node of the pipeline: a lilac-dark disc (`#2A2160`).
        static let sharedNode = Color(hex: 0x2A2160)
        /// The yellow light behind the "Up next" card (`rgba(255,214,10,.14)`) and its edge (`.35`).
        static let upNextGlow = Color(hex: 0xFFD60A, opacity: 0.14)
        static let upNextRim = Color(hex: 0xFFD60A, opacity: 0.35)

        /// The dark well a take's thumbnail sits in, at its own frame.
        static let thumbnailWell = Color(hex: 0x0E0E10)

        /// Placeholder behind a take until its poster frame loads.
        static let thumbnailTop = Color(hex: 0x7A6250)
        static let thumbnailBottom = Color(hex: 0x2A211C)

        /// The dark glass pill over a poster (a stage, "×3").
        static let posterPill = Color(hex: 0x0E101C, opacity: 0.7)

        /// Duration label over a thumbnail.
        static let durationBadge = Color.black.opacity(0.6)

        /// Behind white: the Share swipe action of a take in the list (Delete is `dangerFill`). 5.2:1 under white; the yellow it had
        /// before (`acc`) is 1.4:1.
        static let shareAction = Color(hex: 0x0A64F0)

        /// Tiles of the "Your takes" strip over the video.
        static let stripTile = Color(hex: 0x1F2236, opacity: 0.85)
    }
}
