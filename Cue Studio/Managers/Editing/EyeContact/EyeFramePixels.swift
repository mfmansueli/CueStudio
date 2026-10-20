//
//  EyeFramePixels.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A locked BGRA frame's bytes.
///
/// `@unchecked Sendable`: only read, by both eyes' threads at once, while the renderer keeps the frame locked for the whole call.
nonisolated struct EyeFramePixels: @unchecked Sendable {
    let base: UnsafeMutablePointer<UInt8>
    let width: Int, height: Int, rowBytes: Int

    /// The upright pixels of `rect` (whole pixels), each read from its buffer pixel (a quarter turn maps centre to centre).
    func patch(_ rect: CGRect, bufferFromUpright: CGAffineTransform) -> EyePatch {
        let patchWidth = Int(rect.width), patchHeight = Int(rect.height)
        var channels = Array(repeating: [Float](repeating: 0, count: patchWidth * patchHeight), count: 3)
        for py in 0..<patchHeight {
            for px in 0..<patchWidth {
                let center = CGPoint(x: rect.minX + CGFloat(px) + 0.5, y: rect.minY + CGFloat(py) + 0.5).applying(bufferFromUpright)
                let bx = min(max(Int(floor(center.x)), 0), width - 1), by = min(max(Int(floor(center.y)), 0), height - 1)
                let pixel = base + by * rowBytes + bx * 4
                for channel in 0..<3 { channels[channel][py * patchWidth + px] = Float(pixel[channel]) }
            }
        }
        return EyePatch(width: patchWidth, height: patchHeight, channels: channels)
    }
}
