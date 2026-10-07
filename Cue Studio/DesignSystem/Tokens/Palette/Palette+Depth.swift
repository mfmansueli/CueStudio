//
//  Palette+Depth.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The depth of a card (`cardDepth(_:openEdges:edge:)`): two shadows under it, a little light on its top edge and the hairline
    /// around it. The page is `#0A0B12`, so a shadow alone is hard to see on it; the light on the edge is what makes the card read
    /// as raised, and the hairline is what keeps its corners defined. All of it is decoration around the card, never behind its text,
    /// so none of it changes a contrast measured on `surface`.
    enum Depth {
        /// The wide, soft shadow that lifts the card off the sky.
        static let ambient = Color.black.opacity(0.5)
        /// The tight one right under the card's lower edge.
        static let contact = Color.black.opacity(0.5)
        /// Light catching the top edge: the violet of `glassBorder`, brighter, fading out by the middle of the card.
        static let rim = Color(hex: 0xB4A7FF, opacity: 0.38)
        /// The faint violet edge all around a card: the one the Scripts groups and the Profile blocks have always had.
        static let edge = Palette.glassBorder.opacity(0.7)
    }
}
