//
//  SplitSeamDrawing.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// The seam of a split screen drawn over the two areas (`SplitSeam`), in Core Image coordinates on a frame `height` tall: a
/// thin line; the two pictures blurred into each other in a soft band, strongest on the seam (Blur); or a dark band, darkest
/// on the seam (Shadow). Only the band is worked on, never the whole frame.
nonisolated enum SplitSeamDrawing {
    /// How dark Shadow gets on the seam.
    static let shadowStrength: CGFloat = 0.7

    static func draw(_ seam: SplitSeam, on image: CIImage, areas: SplitPlacement.Areas, height: CGFloat) -> CIImage {
        func flipped(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height) }
        let horizontal = areas.main.minX == areas.support.minX
        switch seam {
        case .none:
            return image
        case .line:
            guard let divider = areas.divider else { return image }
            return CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.9)).cropped(to: flipped(divider)).composited(over: image)
        case .blur:
            guard let band = areas.band.map(flipped) else { return image }
            // The band blurred (from the pictures on both sides of it), laid over through a mask that is solid on the seam and
            // clear at the band's edges.
            let radius = (horizontal ? band.height : band.width) / 4
            let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: band)
            let mask = ramp(in: band, horizontal: horizontal, edge: CIColor(red: 1, green: 1, blue: 1, alpha: 0), middle: .white)
            return blurred.applyingFilter("CIBlendWithAlphaMask", parameters: [
                kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask,
            ]).cropped(to: image.extent)
        case .shadow:
            guard let band = areas.band.map(flipped) else { return image }
            let shade = ramp(
                in: band, horizontal: horizontal, edge: CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                middle: CIColor(red: 0, green: 0, blue: 0, alpha: shadowStrength)
            )
            return shade.composited(over: image)
        }
    }

    /// A band shaded from `edge` at both of its long sides to `middle` along its middle line.
    private static func ramp(in band: CGRect, horizontal: Bool, edge: CIColor, middle: CIColor) -> CIImage {
        func gradient(from start: CGPoint, to end: CGPoint, half: CGRect) -> CIImage {
            let filter = CIFilter.smoothLinearGradient()
            filter.point0 = start
            filter.point1 = end
            filter.color0 = edge
            filter.color1 = middle
            return (filter.outputImage ?? CIImage.empty()).cropped(to: half)
        }
        if horizontal {
            let low = CGRect(x: band.minX, y: band.minY, width: band.width, height: band.height / 2)
            let high = CGRect(x: band.minX, y: band.midY, width: band.width, height: band.height / 2)
            return gradient(from: CGPoint(x: band.midX, y: band.minY), to: CGPoint(x: band.midX, y: band.midY), half: low)
                .composited(over: gradient(from: CGPoint(x: band.midX, y: band.maxY), to: CGPoint(x: band.midX, y: band.midY), half: high))
        }
        let left = CGRect(x: band.minX, y: band.minY, width: band.width / 2, height: band.height)
        let right = CGRect(x: band.midX, y: band.minY, width: band.width / 2, height: band.height)
        return gradient(from: CGPoint(x: band.minX, y: band.midY), to: CGPoint(x: band.midX, y: band.midY), half: left)
            .composited(over: gradient(from: CGPoint(x: band.maxX, y: band.midY), to: CGPoint(x: band.midX, y: band.midY), half: right))
    }
}
