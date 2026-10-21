//
//  EyePatch.swift
//  Cue Studio
//

import Foundation

/// A small upright picture around one eye, as three planes of 0–255 values (blue, green, red) plus where Eye Contact changed it
/// (`alpha`, 0–1). What `EyeRedraw` reads and writes; `EyeContactRenderer` cuts it from a frame and lays it back. Pure.
nonisolated struct EyePatch: Sendable {
    let width: Int
    let height: Int
    /// Blue, green, red, each `width × height`, row by row from the top.
    var channels: [[Float]]
    var alpha: [Float]

    init(width: Int, height: Int, channels: [[Float]]) {
        self.width = width
        self.height = height
        self.channels = channels
        alpha = [Float](repeating: 0, count: width * height)
    }

    var count: Int { width * height }

    /// Bilinear sample at (`x`, `y`) (pixel centres at whole numbers), clamped to the edges.
    func sample(_ channel: Int, x: Float, y: Float) -> Float {
        let cx = min(max(x, 0), Float(width - 1)), cy = min(max(y, 0), Float(height - 1))
        let x0 = Int(cx), y0 = Int(cy)
        let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
        let fx = cx - Float(x0), fy = cy - Float(y0)
        let plane = channels[channel]
        let top = plane[y0 * width + x0] * (1 - fx) + plane[y0 * width + x1] * fx
        let bottom = plane[y1 * width + x0] * (1 - fx) + plane[y1 * width + x1] * fx
        return top * (1 - fy) + bottom * fy
    }
}
