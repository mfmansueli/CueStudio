//
//  BlurDrawing.swift
//  Cue Studio
//

import CoreImage
import Foundation

/// Hides Blur areas on a frame (`BlurShown`), for the compositor (the main video, and the photos and videos over the take) and
/// the cover alike: drawn on the footage's upright frame, before it's steadied, cropped, zoomed or placed, so whatever moves
/// the picture afterwards takes the hidden part along.
///
/// None of the three ways leaves enough of the picture to recognize a face (research in DESIGN_PROJECT §54): Pixelate is a
/// few blocks across the area, each the average of what's under it, on a grid anchored to the area (so the blocks travel with
/// what they hide instead of sweeping across it frame after frame, which lets a moving mosaic be read back); Blur brings the
/// area down to a handful of pixels and spreads them again; Solid is an opaque bar. A soft edge spreads outward only.
nonisolated enum BlurDrawing {
    /// `image` (an upright frame) with each area hidden.
    static func apply(_ shown: [BlurShown], to image: CIImage) -> CIImage {
        guard !shown.isEmpty else { return image }
        var result = image
        for item in shown {
            let rect = pixelRect(item.box, in: image.extent)
            guard rect.width >= 1, rect.height >= 1 else { continue }
            result = hide(rect, as: item, in: result)
        }
        return result
    }

    /// The box (fractions from the top left) on `extent`, in Core Image's coordinates (y up), on whole pixels.
    static func pixelRect(_ box: NormalizedBox, in extent: CGRect) -> CGRect {
        CGRect(
            x: extent.minX + box.x * extent.width, y: extent.minY + (1 - box.y - box.height) * extent.height,
            width: box.width * extent.width, height: box.height * extent.height
        ).integral.intersection(extent)
    }

    /// How far a soft edge spreads out of an area whose shorter side is `short` pixels.
    static func featherReach(_ feather: Double, short: CGFloat) -> CGFloat {
        CGFloat(min(max(feather, 0), 1)) * 0.35 * short
    }

    // MARK: - Hiding

    private static func hide(_ rect: CGRect, as item: BlurShown, in image: CIImage) -> CIImage {
        let short = min(rect.width, rect.height)
        let feather = featherReach(item.feather, short: short)
        let reach = rect.insetBy(dx: -feather, dy: -feather).intersection(image.extent)
        let cover: CIImage
        switch item.style {
        case .solid:
            cover = CIImage(color: CIColor(red: item.color.red, green: item.color.green, blue: item.color.blue)).cropped(to: reach)
        case .pixelate:
            cover = pixelated(image, rect: rect, reach: reach, blocks: item.pixelBlocks)
        case .blur:
            cover = blurred(image, rect: rect, reach: reach, steps: item.blurSteps)
        }
        let mask = shapeMask(rect, shape: item.shape, feather: feather)
        return cover.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask,
        ])
    }

    /// Blocks `rect.short / blocks` pixels wide over `reach`, the grid starting at the area's corner, each the average of what's
    /// under it (a Lanczos reduction, then each pixel widened back without smoothing).
    private static func pixelated(_ image: CIImage, rect: CGRect, reach: CGRect, blocks: Double) -> CIImage {
        let block = max(2, min(rect.width, rect.height) / CGFloat(max(1, blocks)))
        // The grid anchored to the area's corner, grown by whole blocks to cover the soft edge.
        let left = rect.minX - ceil((rect.minX - reach.minX) / block) * block
        let bottom = rect.minY - ceil((rect.minY - reach.minY) / block) * block
        let columns = ceil((reach.maxX - left) / block), rows = ceil((reach.maxY - bottom) / block)
        let grid = CGRect(x: left, y: bottom, width: columns * block, height: rows * block)
        let source = image.clampedToExtent().cropped(to: grid)
            .transformed(by: CGAffineTransform(translationX: -grid.minX, y: -grid.minY))
        let small = shrunk(source, by: 1 / block)
            .cropped(to: CGRect(x: 0, y: 0, width: columns, height: rows))
        return small
            .samplingNearest()
            .transformed(by: CGAffineTransform(scaleX: grid.width / columns, y: grid.height / rows))
            .transformed(by: CGAffineTransform(translationX: grid.minX, y: grid.minY))
            .cropped(to: reach)
    }

    /// The area brought down to `steps` pixels across its shorter side, softened and spread back over `reach`.
    private static func blurred(_ image: CIImage, rect: CGRect, reach: CGRect, steps: Double) -> CIImage {
        let short = min(rect.width, rect.height)
        let factor = CGFloat(max(1, steps)) / max(1, short)
        // A little of what's around comes along, so the edge of the area isn't a hard seam.
        let around = reach.insetBy(dx: -short * 0.2, dy: -short * 0.2).intersection(image.extent)
        let source = image.clampedToExtent().cropped(to: around)
            .transformed(by: CGAffineTransform(translationX: -around.minX, y: -around.minY))
        // Spread back with a B-spline: smooth, without the creases a straight stretch of so few pixels leaves.
        return shrunk(source, by: factor)
            .applyingFilter("CIBicubicScaleTransform", parameters: [
                kCIInputScaleKey: 1 / factor, kCIInputAspectRatioKey: 1, "inputB": 1, "inputC": 0,
            ])
            .transformed(by: CGAffineTransform(translationX: around.minX, y: around.minY))
            .cropped(to: reach)
    }

    /// `image` (finite, from the origin) brought down by `factor` in few passes: first a quarter at a time by sampling between
    /// pixels, which Core Image folds into the next pass, then Lanczos for the rest. Each pass costs the iPhone more than its
    /// pixels (BlurAreaDeviceTests: three areas took the preview from 224 to 49 frames a second with Lanczos alone).
    private static func shrunk(_ image: CIImage, by factor: CGFloat) -> CIImage {
        let first = factor < 0.25 ? 0.25 : 1
        return image
            .transformed(by: CGAffineTransform(scaleX: first, y: first))
            .clampedToExtent()
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: factor / first, kCIInputAspectRatioKey: 1])
    }

    /// White over the area (fully over all of it), fading out over `feather` pixels around it.
    private static func shapeMask(_ rect: CGRect, shape: BlurShape, feather: CGFloat) -> CIImage {
        let white = CIColor(red: 1, green: 1, blue: 1), clear = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        switch shape {
        case .rectangle:
            let hard = CIImage(color: white).cropped(to: rect)
            guard feather >= 1 else { return hard }
            // Four smooth ramps from black to white, one per side, multiplied (opaque, so multiplying is a product): drawn in the
            // same pass as the rest, where a blurred rectangle took eight.
            let black = CIColor(red: 0, green: 0, blue: 0)
            let sides = [
                (CGPoint(x: rect.minX - feather, y: 0), CGPoint(x: rect.minX, y: 0)), (CGPoint(x: rect.maxX + feather, y: 0), CGPoint(x: rect.maxX, y: 0)),
                (CGPoint(x: 0, y: rect.minY - feather), CGPoint(x: 0, y: rect.minY)), (CGPoint(x: 0, y: rect.maxY + feather), CGPoint(x: 0, y: rect.maxY)),
            ]
            let ramps = sides.compactMap { from, to in
                CIFilter(name: "CISmoothLinearGradient", parameters: [
                    "inputPoint0": CIVector(cgPoint: from), "inputPoint1": CIVector(cgPoint: to), "inputColor0": black, "inputColor1": white,
                ])?.outputImage
            }
            return ramps.dropFirst()
                .reduce(ramps.first ?? hard) { $0.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: $1]) }
                .cropped(to: rect.insetBy(dx: -feather, dy: -feather))
        case .oval:
            // A circle as wide as the area, its fade beyond its edge, squeezed to the area's height.
            let radius = rect.width / 2
            let gradient = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: 0, y: 0), "inputRadius0": radius, "inputRadius1": radius + max(1, feather),
                "inputColor0": white, "inputColor1": clear,
            ])?.outputImage ?? CIImage(color: white)
            return gradient
                .transformed(by: CGAffineTransform(scaleX: 1, y: rect.height / max(1, rect.width)))
                .transformed(by: CGAffineTransform(translationX: rect.midX, y: rect.midY))
                .cropped(to: rect.insetBy(dx: -feather - 1, dy: -feather - 1))
        }
    }
}
