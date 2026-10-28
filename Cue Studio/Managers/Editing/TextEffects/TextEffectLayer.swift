//
//  TextEffectLayer.swift
//  Cue Studio
//

import Foundation

/// One layer of a text effect, an image per piece (letter or word) placed in the drawing: all the pieces' shadows go under
/// all their bodies, so a letter's shadow or depth never falls on its neighbour's face. The composer moves each piece's
/// images together and lights them by their role.
nonisolated struct TextEffectLayer: @unchecked Sendable {
    enum Role: Sendable {
        /// A drop shadow: fainter as its letter lifts away from it.
        case shadow
        /// A dark veil behind a glow, so it reads over a bright picture.
        case backing
        /// Light around the letters: as bright as they are lit.
        case halo
        /// A neon tube before it lights.
        case unlit
        /// Everything drawn behind the faces: an outline, a rim, depth.
        case body
        /// The letters themselves: what a band of light crossing them is masked by.
        case face
    }

    let role: Role
    /// One per piece, in the layout's order; nil where the layer draws nothing for it.
    var images: [TextEffectSprite?]
}
