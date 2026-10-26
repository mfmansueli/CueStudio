//
//  BlurLook.swift
//  Cue Studio
//

import Foundation

/// How a Blur area hides what's under it: its way, shape, strength and soft edge. A new area starts with the look the creator
/// last gave one in this video's edit (kept with the edit, so it's there when the editor opens again: the owner's choice, 26/10),
/// and the first one with `initial` (the owner's choice, 26/10: an oval, Blur at 60%, a 50% soft edge, which hides a face
/// without looking like a sticker).
nonisolated struct BlurLook: Codable, Hashable, Sendable {
    var style: BlurStyle
    var shape: BlurShape
    var strength: Double
    var feather: Double

    static let initial = BlurLook(style: .blur, shape: .oval, strength: 0.6, feather: 0.5)

    init(style: BlurStyle, shape: BlurShape, strength: Double, feather: Double) {
        self.style = style
        self.shape = shape
        self.strength = strength
        self.feather = feather
    }

    /// The look `region` has now.
    init(_ region: BlurRegion) {
        self.init(style: region.style, shape: region.shape, strength: region.strength, feather: region.feather)
    }

    /// `region` with this look (where it is and what it follows don't change).
    func applied(to region: BlurRegion) -> BlurRegion {
        var next = region
        next.style = style
        next.shape = shape
        next.strength = strength
        next.feather = feather
        return next
    }
}
