//
//  TransitionDrawing.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// The transitions that need more than a blend, drawn with Core Image's own filters (no kernel of Cue's): from the outgoing
/// frame `from`, the incoming one `to` and how far through it is (0 to 1). Pure functions of their inputs, so the preview and
/// the export draw the same frames.
///
/// The motion of each one follows GL Transitions (https://github.com/gl-transitions/gl-transitions, MIT, "Copyright (c)
/// 2017-present gl-transitions contributors"; reference commit c06c4905958446b7da2d121b12942495e18c99c0), rewritten here, not
/// copied: CrossZoom (rectalogic, after glfx.js by Evan Wallace, MIT), LinearBlur (Gaëtan Renaudeau), Overexposure (Ben Zhang),
/// Directional (Gaëtan Renaudeau), zoomInOut (OllyOllyOlly) and directionalwipe (Gaëtan
/// Renaudeau). See `THIRD_PARTY_NOTICES.md`.
nonisolated enum TransitionDrawing {
    static func draw(_ transition: EditTransition, from: CIImage, to: CIImage, progress p: Double) -> CIImage {
        let extent = from.extent
        let p = min(max(p, 0), 1)
        let result: CIImage = switch transition {
        case .zoom: zoom(from, to, p, extent)
        case .blur: blurred(from, to, p, extent)
        case .flash: flash(from, to, p)
        case .push: push(from, to, p, extent)
        case .punch: punch(from, to, p, extent)
        case .wipe: wipe(from, to, p, extent)
        case .hardCut, .dissolve, .fade, .slide: mix(from, to, p)
        }
        return result.cropped(to: extent)
    }

    // MARK: - The transitions

    /// CrossZoom: both sides blurred toward the middle, strongest on the cut; the swap concentrated in the middle.
    private static func zoom(_ from: CIImage, _ to: CIImage, _ p: Double, _ extent: CGRect) -> CIImage {
        let strength = (1 - cos(2 * .pi * p)) / 2
        let swap = p < 0.5 ? pow(2, 10 * (2 * p - 1)) / 2 : 1 - pow(2, -10 * (2 * p - 1)) / 2
        let amount = extent.width * 0.12 * strength
        func zoomed(_ image: CIImage) -> CIImage {
            guard amount > 0.5 else { return image }
            return softened(image, in: extent, by: amount / 16) { small, scale in
                let filter = CIFilter.zoomBlur()
                filter.inputImage = small
                filter.center = CGPoint(x: extent.width / 2 * scale, y: extent.height / 2 * scale)
                filter.amount = Float(amount * scale)
                return filter.outputImage
            }
        }
        return mix(zoomed(from), zoomed(to), swap)
    }

    /// LinearBlur: both sides blurred most on the cut, blended evenly.
    private static func blurred(_ from: CIImage, _ to: CIImage, _ p: Double, _ extent: CGRect) -> CIImage {
        let radius = extent.width * 0.05 * (1 - abs(1 - 2 * p))
        func soft(_ image: CIImage) -> CIImage {
            guard radius > 0.3 else { return image }
            return softened(image, in: extent, by: radius / 4) { small, scale in small.applyingGaussianBlur(sigma: radius * scale) }
        }
        return mix(soft(from), soft(to), p)
    }

    /// Overexposure: the two sides blended and lit up most on the cut (about two stops), so the light parts burn to white and
    /// come back. (GL Transitions adds the two sides with a boost; added in Core Image their opacity would add up too and darken
    /// the frame, so the boost is an exposure on the blend, which looks the same.)
    private static func flash(_ from: CIImage, _ to: CIImage, _ p: Double) -> CIImage {
        // Squared, so the burn is short and centered on the cut instead of covering half of it.
        let stops = 1.6 * pow(sin(.pi * p), 2)
        let lit = mix(from, to, p).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: stops])
        return lit.applyingFilter("CIColorClamp")
    }

    /// Directional: the whole picture moves left, the incoming side right behind the outgoing one, easing in and out.
    /// (directional-easing's circular ease-out finished the move in the first third: on a short cut it read as a jump.)
    private static func push(_ from: CIImage, _ to: CIImage, _ p: Double, _ extent: CGRect) -> CIImage {
        let eased = p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
        let shift = CGFloat(eased) * extent.width
        let outgoing = from.transformed(by: CGAffineTransform(translationX: -shift, y: 0))
        let incoming = to.transformed(by: CGAffineTransform(translationX: extent.width - shift, y: 0))
        return incoming.composited(over: outgoing).composited(over: CIImage(color: .black).cropped(to: extent))
    }

    /// zoomInOut: the outgoing side punches in over the first half, the incoming one settles from close over the second;
    /// never closer than about 1.5× (a face would show its pixels).
    private static func punch(_ from: CIImage, _ to: CIImage, _ p: Double, _ extent: CGRect) -> CIImage {
        func smooth(_ x: Double) -> Double {
            let t = min(max(x, 0), 1)
            return t * t * (3 - 2 * t)
        }
        let limit = 0.33
        let outgoing = zoomed(from, by: 1 / (1 - smooth(2 * p) * limit), in: extent)
        let incoming = zoomed(to, by: 1 / (1 - smooth(2 * (1 - p)) * limit), in: extent)
        return mix(outgoing, incoming, smooth((p - 0.4) / 0.2))
    }

    /// directionalwipe: a soft edge crossing the picture diagonally, the incoming side behind it.
    private static func wipe(_ from: CIImage, _ to: CIImage, _ p: Double, _ extent: CGRect) -> CIImage {
        // Left to right, leaning a little: along (1, 0.35), normalized.
        let length = sqrt(1 + 0.35 * 0.35)
        let direction = CGPoint(x: 1 / length, y: 0.35 / length)
        let corners = [
            CGPoint(x: extent.minX, y: extent.minY), CGPoint(x: extent.maxX, y: extent.minY),
            CGPoint(x: extent.minX, y: extent.maxY), CGPoint(x: extent.maxX, y: extent.maxY),
        ]
        let along = corners.map { $0.x * direction.x + $0.y * direction.y }
        let low = along.min() ?? 0, high = along.max() ?? 1
        let band = (high - low) * 0.18
        let edge = low - band / 2 + (high - low + band) * CGFloat(p)
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: direction.x * (edge - band / 2), y: direction.y * (edge - band / 2))
        gradient.point1 = CGPoint(x: direction.x * (edge + band / 2), y: direction.y * (edge + band / 2))
        gradient.color0 = CIColor.white
        gradient.color1 = CIColor.black
        guard let mask = gradient.outputImage?.cropped(to: extent) else { return mix(from, to, p) }
        let filter = CIFilter.blendWithMask()
        filter.inputImage = to
        filter.backgroundImage = from
        filter.maskImage = mask
        return filter.outputImage ?? mix(from, to, p)
    }

    // MARK: - Building blocks

    /// A blur drawn on a smaller copy of the picture and scaled back: the blur hides the detail the smaller copy loses, and a
    /// 4K frame blurs in a fraction of the time (on an iPhone 15 Pro, a 4K Zoom frame went from 118 to 11 ms and a Blur one from 41 to 13 ms; `EditorExportDeviceTests`).
    /// `detail` is the size, in pixels of the frame, of the finest thing the blur leaves; the copy is never under a quarter.
    private static func softened(
        _ image: CIImage, in extent: CGRect, by detail: CGFloat, blur: (CIImage, CGFloat) -> CIImage?
    ) -> CIImage {
        let scale = min(1, max(0.25, 1 / max(detail, 1)))
        let small = image.clampedToExtent()
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY).scaledBy(x: scale, y: scale))
        let smallExtent = CGRect(x: 0, y: 0, width: extent.width * scale, height: extent.height * scale)
        guard let blurred = blur(small, scale) else { return image }
        return blurred.cropped(to: smallExtent).clampedToExtent()
            .transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale).translatedBy(x: extent.minX * scale, y: extent.minY * scale))
            .cropped(to: extent)
    }

    private static func mix(_ from: CIImage, _ to: CIImage, _ amount: Double) -> CIImage {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = from
        filter.targetImage = to
        filter.time = Float(min(max(0, amount), 1))
        return filter.outputImage ?? from
    }

    /// The picture scaled around its middle, cropped back to its frame.
    private static func zoomed(_ image: CIImage, by scale: Double, in extent: CGRect) -> CIImage {
        let factor = CGFloat(scale)
        guard abs(factor - 1) > 0.000_1 else { return image }
        return image
            .transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                .concatenating(CGAffineTransform(scaleX: factor, y: factor))
                .concatenating(CGAffineTransform(translationX: extent.midX, y: extent.midY)))
            .cropped(to: extent)
    }
}
