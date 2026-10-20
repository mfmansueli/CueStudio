//
//  FaceCrop.swift
//  Cue Studio
//

import Accelerate
import CoreGraphics
import CoreVideo
import Foundation

/// Cuts a `FaceRegion` out of a recording's frame into the face landmarks' 256-pixel square, on the CPU (vImage), so an analysis
/// runs where the GPU isn't available (an export in the background), and measures how sharp the eyes are in it.
///
/// `@unchecked Sendable`: its buffers are only touched under `lock`.
nonisolated final class FaceCrop: @unchecked Sendable {
    private let lock = NSLock()
    private var crop: CVPixelBuffer?

    /// The region of `frame` (a BGRA buffer in the file's orientation) whose upright pixels `uprightFromBuffer` maps, as a 256 × 256
    /// BGRA buffer (outside the frame: black). The buffer is reused by the next call.
    func cut(_ region: FaceRegion, from frame: CVPixelBuffer, uprightFromBuffer: CGAffineTransform) -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        let side = FaceRegion.cropSide
        if crop == nil { crop = Self.makeBuffer(side: side) }
        guard let crop, CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_32BGRA else { return nil }
        // vImage takes the map from source pixels to destination pixels, both with their origin at the bottom left (measured: a
        // top-left map put the face off the crop).
        let frameHeight = Double(CVPixelBufferGetHeight(frame))
        let flipSource = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: frameHeight)
        let flipCrop = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(side))
        let cropFromBuffer = flipSource
            .concatenating(Self.bufferFromCrop(region, uprightFromBuffer: uprightFromBuffer).inverted())
            .concatenating(flipCrop)
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        CVPixelBufferLockBaseAddress(crop, [])
        defer {
            CVPixelBufferUnlockBaseAddress(crop, [])
            CVPixelBufferUnlockBaseAddress(frame, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(frame), let targetData = CVPixelBufferGetBaseAddress(crop) else { return nil }
        var source = vImage_Buffer(
            data: sourceData, height: vImagePixelCount(CVPixelBufferGetHeight(frame)), width: vImagePixelCount(CVPixelBufferGetWidth(frame)),
            rowBytes: CVPixelBufferGetBytesPerRow(frame)
        )
        var target = vImage_Buffer(
            data: targetData, height: vImagePixelCount(side), width: vImagePixelCount(side), rowBytes: CVPixelBufferGetBytesPerRow(crop)
        )
        var transform = vImage_CGAffineTransform(
            a: cropFromBuffer.a, b: cropFromBuffer.b, c: cropFromBuffer.c, d: cropFromBuffer.d, tx: cropFromBuffer.tx, ty: cropFromBuffer.ty
        )
        var black: [UInt8] = [0, 0, 0, 255]
        let flags = vImage_Flags(kvImageBackgroundColorFill | kvImageHighQualityResampling)
        let error = vImageAffineWarpCG_ARGB8888(&source, &target, nil, &transform, &black, flags)
        return error == kvImageNoError ? crop : nil
    }

    /// Crop pixels → the frame's buffer pixels.
    static func bufferFromCrop(_ region: FaceRegion, uprightFromBuffer: CGAffineTransform) -> CGAffineTransform {
        region.cropToUpright.concatenating(uprightFromBuffer.inverted())
    }

    /// How sharp `crop` is inside `box` (crop pixels): the variance of the Laplacian of its luma. Comparable only between crops of
    /// the same face at the same size, which is how it's used.
    static func sharpness(of crop: CVPixelBuffer, in box: CGRect) -> Double {
        CVPixelBufferLockBaseAddress(crop, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(crop, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(crop)?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        let width = CVPixelBufferGetWidth(crop), height = CVPixelBufferGetHeight(crop), rowBytes = CVPixelBufferGetBytesPerRow(crop)
        let x0 = max(1, Int(box.minX)), x1 = min(width - 1, Int(box.maxX.rounded(.up)))
        let y0 = max(1, Int(box.minY)), y1 = min(height - 1, Int(box.maxY.rounded(.up)))
        guard x1 - x0 > 2, y1 - y0 > 2 else { return 0 }
        func luma(_ x: Int, _ y: Int) -> Double {
            let pixel = base + y * rowBytes + x * 4
            return 0.114 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.299 * Double(pixel[2])
        }
        var sum = 0.0, squares = 0.0, count = 0.0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let laplacian = luma(x - 1, y) + luma(x + 1, y) + luma(x, y - 1) + luma(x, y + 1) - 4 * luma(x, y)
                sum += laplacian
                squares += laplacian * laplacian
                count += 1
            }
        }
        let mean = sum / count
        return max(0, squares / count - mean * mean)
    }

    private static func makeBuffer(side: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
        CVPixelBufferCreate(nil, side, side, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        return buffer
    }
}
