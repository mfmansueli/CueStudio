//
//  EyeContactRenderer.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

/// Draws Eye Contact on one frame of a recording, on its own pixels (before it's turned upright, cropped, looked or blended), so the
/// preview, the export and the cover move the eyes exactly the same way at any output size.
///
/// Each eye is cut from the frame as a small upright patch on whole pixels (a recording's turns are quarter turns, so the patch's
/// unchanged pixels are the frame's own, bit for bit), redrawn on the CPU (`EyeRedraw`: it runs where the GPU isn't available, as in
/// an export in the background) and laid back over the frame where it changed.
nonisolated final class EyeContactRenderer: Sendable {
    init() {}

    /// `image` (the frame as `CIImage(cvPixelBuffer: source)`) with the eyes of `frame` redrawn; `transform` is the recording track's
    /// (how its pixels stand upright). Unchanged when the eyes are out of the picture or the frame isn't BGRA.
    func corrected(_ image: CIImage, source: CVPixelBuffer, transform: CGAffineTransform, frame: EyeContactFrame) -> CIImage {
        patches(source: source, transform: transform, frame: frame, colorSpace: image.colorSpace).reduce(image) { $1.composited(over: $0) }
    }

    /// The redrawn eyes as patches in the frame's Core Image coordinates (origin at the bottom left), transparent where nothing
    /// changed.
    func patches(source: CVPixelBuffer, transform: CGAffineTransform, frame: EyeContactFrame, colorSpace: CGColorSpace?) -> [CIImage] {
        guard frame.eyes.count == 2, frame.degrees > 0, CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA else { return [] }
        let width = CVPixelBufferGetWidth(source), height = CVPixelBufferGetHeight(source)
        let upright = CGRect(x: 0, y: 0, width: width, height: height).applying(transform)
        let uprightFromBuffer = transform.concatenating(CGAffineTransform(translationX: -upright.minX, y: -upright.minY))
        let bufferFromUpright = uprightFromBuffer.inverted()
        CVPixelBufferLockBaseAddress(source, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(source)?.assumingMemoryBound(to: UInt8.self) else { return [] }
        let pixels = EyeFramePixels(base: base, width: width, height: height, rowBytes: CVPixelBufferGetBytesPerRow(source))
        // The two eyes are redrawn at the same time (each takes a few milliseconds on the CPU).
        let results = EyePatchResults(count: frame.eyes.count)
        DispatchQueue.concurrentPerform(iterations: frame.eyes.count) { index in
            let eye = frame.eyes[index].scaled(to: upright.size)
            guard let rect = Self.patchRect(eye, within: upright.size) else { return }
            var patch = pixels.patch(rect, bufferFromUpright: bufferFromUpright)
            let local = SIMD2(Double(rect.minX), Double(rect.minY))
            let placed = EyeShape(contour: eye.contour.map { $0 - local }, iris: eye.iris - local, irisRadius: eye.irisRadius)
            EyeRedraw.redraw(&patch, eye: placed, degrees: frame.degrees)
            guard patch.alpha.contains(where: { $0 > 0 }), let image = Self.image(patch, colorSpace: colorSpace) else { return }
            // Patch (Core Image, origin bottom left) → patch rows from the top → upright → buffer (rows from the top) → the frame's
            // Core Image coordinates.
            let place = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.height)
                .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
                .concatenating(bufferFromUpright)
                .concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height)))
            results.set(index, image.transformed(by: place))
        }
        return results.images
    }

    /// The upright pixels around `eye` the redraw needs (the lid's lift reaches high above it), on whole pixels within the frame;
    /// nil when the eye isn't wholly in it.
    static func patchRect(_ eye: EyeShape, within size: CGSize) -> CGRect? {
        let width = eye.frame.width
        let xs = eye.contour.map(\.x), ys = eye.contour.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max(), width > 4 else { return nil }
        let x0 = floor(minX - 0.35 * width), y0 = floor(minY - 0.8 * width)
        let x1 = ceil(maxX + 0.35 * width), y1 = ceil(maxY + 0.45 * width)
        guard x0 >= 0, y0 >= 0, x1 <= Double(size.width), y1 <= Double(size.height) else { return nil }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// The patch as a premultiplied RGBA image (its first row at the top).
    private static func image(_ patch: EyePatch, colorSpace: CGColorSpace?) -> CIImage? {
        var bytes = [UInt8](repeating: 0, count: patch.count * 4)
        for index in 0..<patch.count {
            let alpha = min(max(patch.alpha[index], 0), 1)
            bytes[index * 4] = UInt8((patch.channels[2][index] * alpha).rounded())
            bytes[index * 4 + 1] = UInt8((patch.channels[1][index] * alpha).rounded())
            bytes[index * 4 + 2] = UInt8((patch.channels[0][index] * alpha).rounded())
            bytes[index * 4 + 3] = UInt8((alpha * 255).rounded())
        }
        let space = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        return CIImage(
            bitmapData: Data(bytes), bytesPerRow: patch.width * 4, size: CGSize(width: patch.width, height: patch.height), format: .RGBA8,
            colorSpace: space
        )
    }
}
