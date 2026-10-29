//
//  SkinImageMath.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// The arithmetic Skin's filters do on pictures, with Core Image's own filters and no custom kernel (the same code runs in the preview, the export,
/// the cover and the tests). Core Image works in floating point, so a colour matrix keeps negative numbers: a signed difference is a matrix and an
/// addition. Subtract and Divide blend modes clamp (at 0, and at 1), which is what a rise and a share need.
nonisolated enum SkinImageMath {
    /// `CIColorMatrix`: each output channel is a combination of the input's (red, green, blue, alpha) plus a bias; alpha stays.
    static func matrix(_ image: CIImage, red: [Double], green: [Double], blue: [Double], bias: [Double] = [0, 0, 0, 0]) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = vector(red)
        filter.gVector = vector(green)
        filter.bVector = vector(blue)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = vector(bias)
        return filter.outputImage ?? image
    }

    /// Every colour channel times `factor`, plus `offset`.
    static func scaled(_ image: CIImage, by factor: Double, plus offset: Double = 0) -> CIImage {
        matrix(image, red: [factor, 0, 0, 0], green: [0, factor, 0, 0], blue: [0, 0, factor, 0], bias: [offset, offset, offset, 0])
    }

    /// `CIColorPolynomial`: each channel is `c0 + c1·x + c2·x² + c3·x³`; alpha stays.
    static func polynomial(_ image: CIImage, red: [Double], green: [Double], blue: [Double]) -> CIImage {
        let filter = CIFilter.colorPolynomial()
        filter.inputImage = image
        filter.redCoefficients = vector(red)
        filter.greenCoefficients = vector(green)
        filter.blueCoefficients = vector(blue)
        filter.alphaCoefficients = CIVector(x: 0, y: 1, z: 0, w: 0)
        return filter.outputImage ?? image
    }

    /// The same cubic on the three channels.
    static func polynomial(_ image: CIImage, _ coefficients: [Double]) -> CIImage {
        polynomial(image, red: coefficients, green: coefficients, blue: coefficients)
    }

    /// Every channel kept between 0 and 1.
    static func clamped(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorClamp()
        filter.inputImage = image
        filter.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        return filter.outputImage ?? image
    }

    /// Smooth 0…1 over `low`…`high` of each channel (Hermite, like a shader's `smoothstep`).
    static func smoothstep(_ image: CIImage, from low: Double, to high: Double) -> CIImage {
        let scale = 1 / max(high - low, 0.000_1)
        return polynomial(clamped(Self.scaled(image, by: scale, plus: -low * scale)), [0, 0, 3, -2])
    }

    /// The brightness of an encoded picture (ITU-R BT.601, as the skin's tone is measured), as a grey image.
    static func luma(_ image: CIImage) -> CIImage {
        let weights = [0.299, 0.587, 0.114, 0]
        return matrix(image, red: weights, green: weights, blue: weights)
    }

    /// a × b on every channel.
    static func multiplied(_ first: CIImage, _ second: CIImage) -> CIImage {
        let filter = CIFilter.multiplyCompositing()
        filter.inputImage = first
        filter.backgroundImage = second
        return filter.outputImage ?? first
    }

    /// a + b on every colour channel (signed), alpha 1: twice their halfway mix. Not Addition compositing, which adds the
    /// alphas too, so the next colour filter (which reads colours unpremultiplied) would see half the sum.
    static func sum(_ first: CIImage, _ second: CIImage) -> CIImage {
        let filter = CIFilter.mix()
        filter.inputImage = first
        filter.backgroundImage = second
        filter.amount = 0.5
        return scaled(filter.outputImage ?? first, by: 2)
    }

    /// a − b on every colour channel, signed (negative where b is larger).
    static func signedDifference(_ first: CIImage, _ second: CIImage) -> CIImage {
        sum(first, scaled(second, by: -1))
    }

    /// max(0, a − b) on every channel.
    static func positiveDifference(_ first: CIImage, _ second: CIImage) -> CIImage {
        let filter = CIFilter.subtractBlendMode()
        filter.inputImage = second
        filter.backgroundImage = first
        return filter.outputImage ?? first
    }

    /// a ÷ b on every channel, kept between 0 and 1 (b is never 0 where it is used: a variance plus a level).
    static func quotient(_ first: CIImage, _ second: CIImage) -> CIImage {
        let filter = CIFilter.divideBlendMode()
        filter.inputImage = second
        filter.backgroundImage = first
        return filter.outputImage ?? first
    }

    /// `first` where `mask` is white, `second` where it is black, mixed in between.
    static func mixed(_ first: CIImage, over second: CIImage, mask: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = first
        filter.backgroundImage = second
        filter.maskImage = mask
        return filter.outputImage ?? second
    }

    /// `image` blurred by a Gaussian of `sigma` pixels inside `region` (its edge repeated, so nothing dark comes in from outside).
    static func blurred(_ image: CIImage, sigma: Double, region: CGRect) -> CIImage {
        image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: region)
    }

    static func vector(_ values: [Double]) -> CIVector {
        CIVector(x: values[0], y: values[1], z: values[2], w: values[3])
    }
}
