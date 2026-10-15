//
//  VoyageFit.swift
//  Cue Studio
//

import SwiftUI

/// Where 1.3's galaxies go on this screen. The board draws them at fixed places (from the top of Reels' glow down to "YOU" under the creator's
/// galaxy), but the heading above them and the chips below take the room this screen and this language give them. So the galaxies are fitted
/// into the band between the two: centred in it, a little bigger when there is room (up to ×1.12, the owner's call), smaller when there is
/// not, so they never run under the words.
struct VoyageFit: Equatable {
    /// The galaxies' part of the board, top to bottom (board y is the screen's y).
    static let cluster: ClosedRange<CGFloat> = 222...540
    static let maxScale: CGFloat = 1.12
    static let minScale: CGFloat = 0.8
    /// The board's middle: the galaxies grow and shrink about it.
    static let pivotX: CGFloat = 195
    private static let clusterCentreY = (cluster.lowerBound + cluster.upperBound) / 2

    let scale: CGFloat
    /// Where the middle of the galaxies lands on the screen.
    let centreY: CGFloat

    /// As the board has them.
    static let board = VoyageFit(scale: 1, centreY: clusterCentreY)

    init(scale: CGFloat, centreY: CGFloat) {
        self.scale = scale
        self.centreY = centreY
    }

    /// Fitted into `band`, the screen's y from under the heading to above the chips.
    init(band: ClosedRange<CGFloat>) {
        let room = band.upperBound - band.lowerBound
        let height = Self.cluster.upperBound - Self.cluster.lowerBound
        self.init(scale: min(max(room / height, Self.minScale), Self.maxScale), centreY: (band.lowerBound + band.upperBound) / 2)
    }

    /// Turns a context drawing in the board's coordinates into one that draws the galaxies where they fit.
    func apply(to context: inout GraphicsContext) {
        context.translateBy(x: Self.pivotX, y: centreY)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -Self.pivotX, y: -Self.clusterCentreY)
    }

    /// The board's point drawn at `point` of the screen (a tap).
    func boardPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: Self.pivotX + (point.x - Self.pivotX) / scale, y: Self.clusterCentreY + (point.y - centreY) / scale)
    }
}
