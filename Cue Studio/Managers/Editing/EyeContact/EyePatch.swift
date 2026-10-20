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

    init(width: Int, height: Int, fill: Float = 0) {
        self.init(width: width, height: height, channels: Array(repeating: [Float](repeating: fill, count: width * height), count: 3))
    }

    var count: Int { width * height }

    /// The pixel's luma (0–255).
    func luma(_ index: Int) -> Float {
        0.114 * channels[0][index] + 0.587 * channels[1][index] + 0.299 * channels[2][index]
    }

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

    /// Catmull-Rom sample down column `x` at `y` (the lid's lift moves pixels only up and down: sharper than bilinear).
    func sampleColumn(_ channel: Int, x: Int, y: Float) -> Float {
        let plane = channels[channel]
        let base = Int(floor(y)), t = y - Float(base)
        func at(_ row: Int) -> Float { plane[min(max(row, 0), height - 1) * width + x] }
        let p0 = at(base - 1), p1 = at(base), p2 = at(base + 1), p3 = at(base + 2)
        let value = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
        return min(max(value, 0), 255)
    }
}
