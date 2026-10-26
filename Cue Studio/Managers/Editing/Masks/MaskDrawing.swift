//
//  MaskDrawing.swift
//  Cue Studio
//

import CoreImage
import Foundation

/// A photo's or video's mask (`MediaMask`) as Core Image draws it, for the compositor (preview and export alike): the picture,
/// already filling its place, keeps only what the shape shows (outside it, inverted), and the rest goes clear so the video
/// under it shows through. The soft edge spreads to both sides of the shape's line, as editors' masks do.
nonisolated enum MaskDrawing {
    /// How far a mask's soft edge spreads at most, as a share of its media's shorter side.
    static let featherShare: CGFloat = 0.2

    /// `picture` (filling `rect`, Core Image coordinates) with only what `mask` shows where `placement` puts it.
    static func apply(_ mask: MediaMask, placement: MaskPlacement, to picture: CIImage, in rect: CGRect) -> CIImage {
        let alpha = self.alpha(mask.shape, placement: placement.clamped, inverted: mask.inverted, in: rect)
        return picture.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: alpha,
        ])
    }

    /// White where the media shows, black where it doesn't, over `rect`.
    static func alpha(_ shape: MaskShape, placement: MaskPlacement, inverted: Bool, in rect: CGRect) -> CIImage {
        let white = CIColor(red: 1, green: 1, blue: 1), black = CIColor(red: 0, green: 0, blue: 0)
        let short = min(rect.width, rect.height)
        let feather = CGFloat(placement.feather) * featherShare * short
        let width = CGFloat(placement.width) * rect.width, height = CGFloat(placement.height) * rect.height
        // The shape is drawn around the origin, then turned (clockwise on screen is a negative angle with y up) and moved to
        // its center (fractions from the top left of the place).
        let place = CGAffineTransform(rotationAngle: -CGFloat(placement.rotation) * .pi / 180)
            .concatenating(CGAffineTransform(
                translationX: rect.minX + CGFloat(placement.center.x) * rect.width, y: rect.maxY - CGFloat(placement.center.y) * rect.height
            ))
        var shapeImage: CIImage
        switch shape {
        case .rectangle:
            let radius = CGFloat(placement.corners) * min(width, height) / 2
            shapeImage = rounded(CGRect(x: -width / 2, y: -height / 2, width: width, height: height), radius: radius, color: white)
            if feather >= 1 { shapeImage = shapeImage.applyingGaussianBlur(sigma: Double(feather) / 2) }
        case .circle:
            let radius = max(1, width / 2)
            shapeImage = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: 0, y: 0), "inputRadius0": max(0, radius - feather / 2),
                "inputRadius1": radius + feather / 2 + 0.5, "inputColor0": white, "inputColor1": black,
            ])?.outputImage ?? CIImage(color: white)
            shapeImage = shapeImage.transformed(by: CGAffineTransform(scaleX: 1, y: height / max(1, width)))
        case .line:
            // The side above the line shows (before it's turned).
            shapeImage = CIFilter(name: "CILinearGradient", parameters: [
                "inputPoint0": CIVector(x: 0, y: -feather / 2 - 0.5), "inputPoint1": CIVector(x: 0, y: feather / 2 + 0.5),
                "inputColor0": black, "inputColor1": white,
            ])?.outputImage ?? CIImage(color: white)
        case .band:
            // As thick as `height` of the place, long enough to cross it at any turn.
            let thickness = CGFloat(placement.height) * rect.height
            let length = (rect.width + rect.height) * 4
            shapeImage = rounded(CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness), radius: 0, color: white)
            if feather >= 1 { shapeImage = shapeImage.applyingGaussianBlur(sigma: Double(feather) / 2) }
        }
        var mask = shapeImage.transformed(by: place)
            .composited(over: CIImage(color: black))
            .cropped(to: rect)
        if inverted { mask = mask.applyingFilter("CIColorInvert") }
        return mask
    }

    private static func rounded(_ rect: CGRect, radius: CGFloat, color: CIColor) -> CIImage {
        guard radius >= 0.5 else { return CIImage(color: color).cropped(to: rect) }
        return CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: rect), "inputRadius": radius, "inputColor": color,
        ])?.outputImage ?? CIImage(color: color).cropped(to: rect)
    }
}
