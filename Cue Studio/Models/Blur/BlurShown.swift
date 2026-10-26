//
//  BlurShown.swift
//  Cue Studio
//

import Foundation

/// A Blur area as one frame draws it (`BlurDrawing`): where on the footage's upright picture, its shape and style, how strong,
/// how soft its edge and the solid bar's color.
nonisolated struct BlurShown: Equatable, Sendable {
    var box: NormalizedBox
    var shape: BlurShape
    var style: BlurStyle
    /// Pixelate's blocks across the shorter side (`BlurRegion.pixelBlocks`).
    var pixelBlocks: Double
    /// Blur's pixels across the shorter side before it's spread again (`BlurRegion.blurSteps`).
    var blurSteps: Double
    var feather: Double
    /// sRGB, 0 to 1.
    var color: (red: Double, green: Double, blue: Double)

    init(_ region: BlurRegion, at time: TimeInterval) {
        box = region.box(at: time)
        shape = region.shape
        style = region.style
        pixelBlocks = region.pixelBlocks
        blurSteps = region.blurSteps
        feather = region.feather
        color = region.color.components
    }

    static func == (lhs: BlurShown, rhs: BlurShown) -> Bool {
        lhs.box == rhs.box && lhs.shape == rhs.shape && lhs.style == rhs.style && lhs.pixelBlocks == rhs.pixelBlocks
            && lhs.blurSteps == rhs.blurSteps && lhs.feather == rhs.feather && lhs.color == rhs.color
    }
}
