//
//  CameraMotion.swift
//  Cue Studio
//

import Foundation

/// The camera's movement between two frames, from how each background tile slid: the slide and turn that best explain the
/// tiles, fitted again without the tiles that stray from them (one with something moving in it is left out). Pure.
nonisolated enum CameraMotion {
    struct Tile: Hashable, Sendable {
        /// The tile's center, in pixels from the frame's center (right and down positive).
        var x: Double
        var y: Double
        /// How far its picture slid, in pixels (right and down positive).
        var dx: Double
        var dy: Double
    }

    /// How far a tile may stray from the fitted motion and still count, in pixels (or more when most tiles stray more).
    static let agreement = 1.0
    /// Fewest agreeing tiles to read a turn from.
    static let tilesForTurn = 4
    /// The tiles must spread at least this far around their middle (pixels, root mean square) for a turn to be read: close
    /// together, a turn can't be told from a slide.
    static let spreadForTurn = 40.0
    /// Most a camera turns between two frames (radians); more is a misreading, and the turn is left out.
    static let largestTurn = 0.03

    /// The camera's slide (pixels, right and down positive) and turn (radians, clockwise positive); nil without tiles. The
    /// slide and turn that best explain every tile are fitted (least squares), the tiles that stray from them are left out
    /// (something moving in them), and the fit is made again on the rest, twice.
    static func estimate(_ tiles: [Tile]) -> (dx: Double, dy: Double, angle: Double)? {
        guard !tiles.isEmpty else { return nil }
        guard tiles.count >= tilesForTurn else { return (median(tiles.map(\.dx)), median(tiles.map(\.dy)), 0) }
        // A first guess robust to a few moving tiles: the median slide, no turn.
        var fit = (dx: median(tiles.map(\.dx)), dy: median(tiles.map(\.dy)), angle: 0.0)
        for _ in 0..<3 {
            let residuals = tiles.map { residual($0, of: fit) }
            let reach = max(agreement, 2.5 * median(residuals))
            let inliers = tiles.indices.filter { residuals[$0] <= reach }.map { tiles[$0] }
            guard inliers.count >= tilesForTurn else { break }
            if let refit = leastSquares(inliers), abs(refit.angle) <= largestTurn {
                fit = refit
            } else {
                fit = (inliers.map(\.dx).reduce(0, +) / Double(inliers.count), inliers.map(\.dy).reduce(0, +) / Double(inliers.count), 0)
            }
        }
        return fit
    }

    /// How far a tile's slide is from what `fit` predicts there.
    private static func residual(_ tile: Tile, of fit: (dx: Double, dy: Double, angle: Double)) -> Double {
        // A small turn θ (clockwise, y down) moves a point (x, y) by θ · (−y, x).
        hypot(tile.dx - (fit.dx - fit.angle * tile.y), tile.dy - (fit.dy + fit.angle * tile.x))
    }

    /// The slide and turn that best explain the tiles' slides: dx = Tx − θ·y, dy = Ty + θ·x, solved on the normal equations.
    private static func leastSquares(_ tiles: [Tile]) -> (dx: Double, dy: Double, angle: Double)? {
        let n = Double(tiles.count)
        var sumX = 0.0, sumY = 0.0, sumR = 0.0, sumDx = 0.0, sumDy = 0.0, sumCross = 0.0
        for tile in tiles {
            sumX += tile.x
            sumY += tile.y
            sumR += tile.x * tile.x + tile.y * tile.y
            sumDx += tile.dx
            sumDy += tile.dy
            sumCross += tile.x * tile.dy - tile.y * tile.dx
        }
        // Tx and Ty in terms of θ from the first two equations, put in the third.
        let spread = n * sumR - sumX * sumX - sumY * sumY
        guard spread / (n * n) >= spreadForTurn * spreadForTurn else { return nil }
        let angle = (n * sumCross - sumX * sumDy + sumY * sumDx) / spread
        let dx = (sumDx + angle * sumY) / n
        let dy = (sumDy - angle * sumX) / n
        return (dx, dy, angle)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
