//
//  Palette+Takes.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Takes: thumbnails, posters and the badges over them.
    enum Takes {
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
    }
}
