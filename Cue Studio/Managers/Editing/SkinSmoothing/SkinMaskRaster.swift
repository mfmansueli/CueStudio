//
//  SkinMaskRaster.swift
//  Cue Studio
//

import Accelerate
import CoreGraphics

/// Draws a face's `SkinMask` from its landmarks, with Core Graphics, in the frame's own pixels so the shapes keep their proportions:
/// - the **skin** is the face inside its jaw and up to a forehead of half the way from the brows to the chin (the landmarks stop at the brows), drawn a
///   little inside its edge, so the jawline, the ears and the hairline are not touched;
/// - **eyes** (with the lids and lashes), **brows** and **lips** are taken out, wider than their outlines, and every edge is feathered;
/// - the **core** is the forehead and the cheeks above the lips, further inside the face, with the features taken out wider still.
/// Nothing here looks at the picture: the hair, the beard and the shadows are left out by the skin tone (`SkinToneAnalyzer`) and by the filter.
nonisolated enum SkinMaskRaster {
    /// How far the skin is drawn inside the jaw's outline.
    private static let insetShare = 0.04

    static func make(_ face: FaceLandmarks, frame: CGSize) -> SkinMask? {
        guard face.isUsable, frame.width > 0, frame.height > 0 else { return nil }
        guard let shape = FaceShape(face, frame: frame) else { return nil }
        let region = shape.region(in: frame)
        guard region.width >= 8, region.height >= 8 else { return nil }
        let width = SkinSmoothingCalibration.maskWidth
        let height = min(max(8, Int((CGFloat(width) * region.height / region.width).rounded())), width * 5 / 2)
        let scale = CGSize(width: CGFloat(width) / region.width, height: CGFloat(height) / region.height)
        let toMask = { (point: CGPoint) in CGPoint(x: (point.x - region.minX) * scale.width, y: (point.y - region.minY) * scale.height) }

        // The skin's edge is feathered widely; the features are cut out of it with a much tighter edge, so a thin brow or an eye is still wholly out.
        let outline = draw(width: width, height: height) { context in
            context.setFillColor(gray: 1, alpha: 1)
            context.addPath(shape.skinPath(inset: insetShare, transform: toMask))
            context.fillPath()
        }
        let features = draw(width: width, height: height) { context in
            shape.paintFeatures(in: context, gray: 1, transform: toMask, widen: 1)
        }
        let soft = boxBlurred(outline, width: width, height: height, radius: max(1, Int((Double(width) * 0.035).rounded())))
        let cut = boxBlurred(features, width: width, height: height, radius: max(1, Int((Double(width) * 0.012).rounded())))
        var skin = soft
        skin.withUnsafeMutableBufferPointer { skinPixels in
            cut.withUnsafeBufferPointer { cutPixels in
                for index in 0..<skinPixels.count { skinPixels[index] = UInt8(Int(skinPixels[index]) * (255 - Int(cutPixels[index])) / 255) }
            }
        }
        let core = draw(width: width, height: height) { context in
            context.saveGState()
            context.addPath(shape.aboveLips(transform: toMask))
            context.clip()
            context.setFillColor(gray: 1, alpha: 1)
            context.addPath(shape.skinPath(inset: insetShare * 3, transform: toMask))
            context.fillPath()
            context.restoreGState()
            shape.paintFeatures(in: context, gray: 0, transform: toMask, widen: 1.5)
        }
        return SkinMask(region: region, width: width, height: height, skin: skin, core: core)
    }

    // MARK: - Drawing

    /// A grey bitmap of `width` × `height`, black, drawn by `body` (y up, from the bottom), as rows from the top.
    private static func draw(width: Int, height: Int, _ body: (CGContext) -> Void) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            body(context)
        }
        return pixels
    }

    /// `pixels` blurred by a box of `2 × radius + 1` pixels, twice (a soft edge, close to a Gaussian), with Accelerate: the work is the library's, so it takes
    /// the same fraction of a millisecond in a Debug build. The edge repeats.
    static func boxBlurred(_ pixels: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0, width > 0, height > 0, pixels.count == width * height else { return pixels }
        var first = pixels
        var second = [UInt8](repeating: 0, count: pixels.count)
        let side = UInt32(radius * 2 + 1)
        first.withUnsafeMutableBytes { firstBytes in
            second.withUnsafeMutableBytes { secondBytes in
                var from = vImage_Buffer(data: firstBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
                var to = vImage_Buffer(data: secondBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
                // Two passes, there and back, so the result ends where it started.
                vImageBoxConvolve_Planar8(&from, &to, nil, 0, 0, side, side, 0, vImage_Flags(kvImageEdgeExtend))
                vImageBoxConvolve_Planar8(&to, &from, nil, 0, 0, side, side, 0, vImage_Flags(kvImageEdgeExtend))
            }
        }
        return first
    }
}
