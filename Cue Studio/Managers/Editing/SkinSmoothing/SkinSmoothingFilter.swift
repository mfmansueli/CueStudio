//
//  SkinSmoothingFilter.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Smooths the skin of one face with Core Image's own filters, no custom kernel. A frequency separation, the way the high-pass skin smoothing of
/// photo editors is done (the idea of YUCIHighPassSkinSmoothing, `THIRD_PARTY_NOTICES.md`), made safe for faces in video:
///
/// 1. **Skin only.** Where to work is the face's mask (`SkinMask`: no eyes, brows or lips) times a gate on the face's own skin tone, so the hair, the
///    beard, the shadows and the background don't count, and don't bleed into the skin either (step 2 blurs only what is skin).
/// 2. **Tone and texture apart.** The skin's tone is the picture blurred over the scale of pores and blemishes (a share of the face's width). The texture
///    is what the picture has over it, read on the green channel, where skin shows its detail best.
/// 3. **Soften the small, keep the big.** Texture under a threshold (`coring`: it grows with the noise measured) is turned down to a quarter; texture over
///    the next one (an edge, a hair, a deep shadow) is left alone; in between it fades. Nothing is added or lifted: the average stays where it was, so
///    there is no whitening, and nothing moves, so there is no reshaping.
/// 4. **Only so much.** The result goes over the picture at the strength the dial gives (`SkinSmoothingCalibration.strength`, 60% at the most) times the
///    mask, so what is not smoothed keeps its pixels exactly.
///
/// The work is done on sRGB-encoded values (the scale the thresholds mean), converted from and to Core Image's linear light, and only inside the
/// face's region, so a 4K frame costs the size of the face and not of the frame.
nonisolated enum SkinSmoothingFilter {
    static func apply(to image: CIImage, face: SkinFace, value: Double) -> CIImage {
        let strength = SkinSmoothingCalibration.strength(value) * min(max(face.presence, 0), 1)
        let region = face.region.intersection(image.extent)
        guard strength > 0.001, !region.isNull, region.width >= 8, region.height >= 8 else { return image }
        let original = image.cropped(to: region)
        let encoded = original.applyingFilter("CILinearToSRGBToneCurve")
        let sigma = SkinSmoothingCalibration.blurSigma(faceWidth: face.width, value: value)

        // 1. Where the skin is: the face's mask times its gate, a little softened.
        let skin = multiplied(face.mask.cropped(to: region), skinGate(of: encoded, tone: face.tone))
        let weight = blurred(skin, sigma: sigma * 0.35, region: region)

        // 2. The tone: the skin blurred without anything that isn't skin.
        let tone = maskedBlur(of: encoded, weight: weight, sigma: sigma, region: region)

        // 3. The texture, softened where it is small.
        let limits = SkinSmoothingCalibration.coring(value: value, noise: face.tone.noise, luma: face.tone.luma)
        let detail = difference(of: channel(encoded, 1), and: channel(tone, 1))
        let gain = coring(detail, soft: limits.soft, edge: limits.edge)
        let smoothed = CIFilter.blendWithMask()
        smoothed.inputImage = encoded
        smoothed.backgroundImage = tone
        smoothed.maskImage = gain

        // 4. Over the picture, as much as the dial says, where the skin is.
        let amount = scaled(weight, by: strength)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = smoothed.outputImage?.applyingFilter("CISRGBToneCurveToLinear")
        blend.backgroundImage = original
        blend.maskImage = amount
        guard let result = blend.outputImage?.cropped(to: region) else { return image }
        return result.composited(over: image)
    }

    // MARK: - Steps

    /// How much each pixel is this face's skin, 0 to 1, from its color: chroma near the face's own, and not much darker than it (hair, beard and
    /// shadows are dark, lashes and brows darker still). A smooth gate, not a cut, so no patch has an edge.
    static func skinGate(of encoded: CIImage, tone: SkinTone) -> CIImage {
        // Chroma and brightness, the chroma centered on the face's (+0.5 so nothing goes negative).
        let measured = matrix(
            encoded, red: [-0.168_736, -0.331_264, 0.5, 0], green: [0.5, -0.418_688, -0.081_312, 0], blue: [0.299, 0.587, 0.114, 0],
            bias: [0.5 - tone.cb, 0.5 - tone.cr, 0, 0]
        )
        // (x − 0.5)² on the two chromas: the squared distance's two parts.
        let squares = polynomial(measured, red: [0.25, -1, 1, 0], green: [0.25, -1, 1, 0], blue: [0, 1, 0, 0])
        let near = tone.chromaReach * tone.chromaReach
        let far = pow(tone.chromaReach + SkinTone.chromaFade, 2)
        let scale = 1 / (far - near)
        let sum = [scale, scale, 0, 0]
        let distance = clamped(matrix(squares, red: sum, green: sum, blue: sum, bias: [-near * scale, -near * scale, -near * scale, 0]))
        let chromaGate = polynomial(distance, red: [1, 0, -3, 2], green: [1, 0, -3, 2], blue: [1, 0, -3, 2])
        // Brightness: skin from 55% of the face's own to 75%; brighter is skin too (a shine).
        let lowest = 0.55 * max(tone.luma, 0.02)
        let ramp = 0.2 * max(tone.luma, 0.02)
        let luma = [0, 0, 1 / ramp, 0]
        let brightness = clamped(matrix(squares, red: luma, green: luma, blue: luma, bias: [-lowest / ramp, -lowest / ramp, -lowest / ramp, 0]))
        let brightnessGate = polynomial(brightness, red: [0, 0, 3, -2], green: [0, 0, 3, -2], blue: [0, 0, 3, -2])
        return multiplied(chromaGate, brightnessGate)
    }

    /// The picture blurred by `sigma`, counting only the pixels `weight` says are skin: (colour × weight) blurred, over weight blurred.
    static func maskedBlur(of encoded: CIImage, weight: CIImage, sigma: Double, region: CGRect) -> CIImage {
        let weighted = CIFilter.blendWithMask()
        weighted.inputImage = encoded
        weighted.backgroundImage = CIImage(color: .clear).cropped(to: region)
        weighted.maskImage = weight
        guard let premultiplied = weighted.outputImage else { return encoded }
        return blurred(premultiplied, sigma: sigma, region: region).unpremultiplyingAlpha().settingAlphaOne(in: region)
    }

    /// The gain on the texture: `flatDetailKept` where it is under `soft`, 1 over `edge`, smooth in between.
    static func coring(_ detail: CIImage, soft: Double, edge: Double) -> CIImage {
        let scale = 1 / max(edge - soft, 0.001)
        let offset = -soft * scale
        let position = clamped(matrix(detail, red: [scale, 0, 0, 0], green: [0, scale, 0, 0], blue: [0, 0, scale, 0], bias: [offset, offset, offset, 0]))
        let kept = SkinSmoothingCalibration.flatDetailKept
        let curve = [kept, 0, 3 * (1 - kept), -2 * (1 - kept)]
        return polynomial(position, red: curve, green: curve, blue: curve)
    }

    // MARK: - Core Image helpers

    private static func blurred(_ image: CIImage, sigma: Double, region: CGRect) -> CIImage {
        image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: region)
    }

    /// One channel (0 red, 1 green, 2 blue) of `image`, as a grey image.
    private static func channel(_ image: CIImage, _ index: Int) -> CIImage {
        var vector = [0.0, 0, 0, 0]
        vector[index] = 1
        return matrix(image, red: vector, green: vector, blue: vector)
    }

    /// |a − b| on every channel.
    private static func difference(of first: CIImage, and second: CIImage) -> CIImage {
        let filter = CIFilter.differenceBlendMode()
        filter.inputImage = first
        filter.backgroundImage = second
        return filter.outputImage ?? first
    }

    private static func multiplied(_ first: CIImage, _ second: CIImage) -> CIImage {
        let filter = CIFilter.multiplyCompositing()
        filter.inputImage = first
        filter.backgroundImage = second
        return filter.outputImage ?? first
    }

    /// A grey image times `factor`.
    private static func scaled(_ image: CIImage, by factor: Double) -> CIImage {
        matrix(image, red: [factor, 0, 0, 0], green: [0, factor, 0, 0], blue: [0, 0, factor, 0])
    }

    private static func clamped(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorClamp()
        filter.inputImage = image
        filter.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        return filter.outputImage ?? image
    }

    /// `CIColorMatrix`: each output channel is a combination of the input's (red, green, blue, alpha) plus a bias; alpha stays.
    private static func matrix(
        _ image: CIImage, red: [Double], green: [Double], blue: [Double], bias: [Double] = [0, 0, 0, 0]
    ) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = vector(red)
        filter.gVector = vector(green)
        filter.bVector = vector(blue)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = vector(bias)
        return filter.outputImage ?? image
    }

    /// `CIColorPolynomial`: each channel is `c0 + c1·x + c2·x² + c3·x³`; alpha stays.
    private static func polynomial(_ image: CIImage, red: [Double], green: [Double], blue: [Double]) -> CIImage {
        let filter = CIFilter.colorPolynomial()
        filter.inputImage = image
        filter.redCoefficients = vector(red)
        filter.greenCoefficients = vector(green)
        filter.blueCoefficients = vector(blue)
        filter.alphaCoefficients = CIVector(x: 0, y: 1, z: 0, w: 0)
        return filter.outputImage ?? image
    }

    private static func vector(_ values: [Double]) -> CIVector {
        CIVector(x: values[0], y: values[1], z: values[2], w: values[3])
    }
}
