//
//  SkinShineFilter.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Skin's anti-shine on one face: the shine on the forehead, the nose and the cheeks comes down, as a little powder would take it. Not the
/// highlights dial: only the shine on the skin changes (the eyes, the teeth and the lips are out of the mask), and the light on the face stays.
///
/// A shine is the light's own colour (near white) added to the skin's, in a patch brighter than the skin right around it; skin that is simply
/// better lit keeps its colour, and the lit side of a face is wide (the dichromatic model, as in Yang, Wang and Ahuja, ECCV 2010, with a
/// morphological top-hat for the peak). Light adds in linear values, so this is worked out in them, on a small copy of the face (a shine has no
/// fine detail; `shineWorkingWidth`):
/// 1. **The skin under the shine:** the face smoothed (`shineSmoothing`, no grain), what is not skin (the eyes, the brows, the hair) filled with
///    the darkest skin near it (never with a shine, nor with a brow's own colour), and opened (eroded, then dilated) at `shineSize`: what is
///    left is the skin's floor, which follows the light across the face, its edges and the terminator of a side light, but not a patch
///    narrower than a shine.
/// 2. **How much brighter, channel by channel:** the smoothed face over that floor, in its brightest channel and in its darkest. Light raises
///    both in the skin's own ratio (`ratio`, darkest over brightest of the face's tone); a shine raises them by the same amount. The part of the
///    darkest channel's rise past that ratio is the white added to the skin, never more than either channel's rise (no channel goes darker
///    than the skin around it: where the camera clipped the brightest channel, little comes off, and the highlight keeps its warmth instead
///    of turning grey).
/// 3. **Only where it was skin:** taken off, the white must leave the skin's own colour (`SkinSmoothingFilter.skinGate` on what is left).
///    Glasses and anything else bright on the face that is not skin fail it and are left as they are.
/// 4. **Down, keeping the skin:** `shineReduction` of that white is taken off the smoothed face's three channels alike (never below 0), and
///    the face's detail goes back over it as a proportion (the pixel over the smoothed face), so a pore stays a pore, a glint inside the shine
///    comes down with it, and no dark pore goes negative into red.
nonisolated enum SkinShineFilter {
    static func apply(to image: CIImage, face: SkinFace, value: Double) -> CIImage {
        let reduction = SkinBeautyCalibration.shineReduction(value) * min(max(face.presence, 0), 1) * face.trust
        let region = face.region.intersection(image.extent)
        guard reduction > 0.001, !region.isNull, region.width >= 8, region.height >= 8 else { return image }
        let original = image.cropped(to: region)

        // 1. The skin's floor, on a small copy of the face.
        let scale = min(1, SkinBeautyCalibration.shineWorkingWidth / max(face.width, 1))
        let toSmall = CGAffineTransform(scaleX: scale, y: scale)
        let small = region.applying(toSmall)
        let sigma = max(face.width * SkinBeautyCalibration.shineSmoothing, 0.5 / scale)
        let smoothed = SkinImageMath.blurred(original, sigma: sigma, region: region)
        let smooth = smoothed.transformed(by: toSmall).cropped(to: small)
        let skin = face.mask.cropped(to: region).transformed(by: toSmall).cropped(to: small)
        let size = max(1, face.width * scale * SkinBeautyCalibration.shineSize)
        let onlySkin = SkinImageMath.mixed(smooth, over: CIImage(color: .white).cropped(to: small), mask: skin)
        let filled = SkinImageMath.mixed(smooth, over: eroded(onlySkin, radius: size, region: small), mask: skin)
        let floor = SkinImageMath.blurred(opened(filled, radius: size, region: small), sigma: size / 2, region: small)

        // 2. The white added to the skin: the darkest channel's rise past what the light alone would give it, never past either channel's rise.
        let ratio = Self.ratio(of: face.tone)
        let riseOfBrightest = SkinImageMath.positiveDifference(maximum(smooth), maximum(floor))
        let riseOfDarkest = SkinImageMath.positiveDifference(minimum(smooth), minimum(floor))
        let estimate = SkinImageMath.positiveDifference(
            SkinImageMath.scaled(riseOfDarkest, by: 1 / (1 - ratio)), SkinImageMath.scaled(riseOfBrightest, by: ratio / (1 - ratio))
        )
        let white = smaller(smaller(estimate, riseOfDarkest), riseOfBrightest)

        // 3. Where there is white enough to be a shine (not the grain of the skin), and taking it off leaves skin.
        let noise = SkinBeautyCalibration.shineNoise
        let underneath = SkinImageMath.positiveDifference(smooth, white).applyingFilter("CILinearToSRGBToneCurve")
        let wasSkin = SkinSmoothingFilter.skinGate(of: underneath, tone: face.tone)
        let shines = SkinImageMath.multiplied(skin, SkinImageMath.multiplied(SkinImageMath.smoothstep(white, from: noise, to: 4 * noise), wasSkin))
        let toFull = toSmall.inverted()
        // Softened, so where the powder stops is never a line.
        let shine = SkinImageMath.blurred(shines, sigma: size / 3, region: small).transformed(by: toFull).cropped(to: region)

        // 4. That white taken off the smoothed face, and the detail laid back over it as a proportion (a quarter of it, so the divide blend,
        // which stops at 1, has room for a glint).
        let base = SkinImageMath.positiveDifference(smoothed, SkinImageMath.scaled(white.transformed(by: toFull).cropped(to: region), by: reduction))
        let detail = SkinImageMath.scaled(SkinImageMath.quotient(SkinImageMath.scaled(original, by: 0.25), smoothed), by: 4)
        let matted = SkinImageMath.multiplied(base, detail)
        let result = SkinImageMath.mixed(matted, over: original, mask: shine).cropped(to: region)
        return result.composited(over: image)
    }

    /// The face's darkest channel over its brightest, in linear values (its skin's colour, from the tone's chroma), kept off 0 and 1 so the
    /// white is defined.
    static func ratio(of tone: SkinTone) -> Double {
        let encoded = [
            tone.luma + 1.402 * tone.cr,
            tone.luma - 0.344_136 * tone.cb - 0.714_136 * tone.cr,
            tone.luma + 1.772 * tone.cb,
        ]
        let linear = encoded.map { value in
            let value = min(max(value, 0), 1)
            return value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        guard let brightest = linear.max(), let darkest = linear.min(), brightest > 0.001 else { return 0.5 }
        return min(max(darkest / brightest, 0.1), 0.9)
    }

    /// `image` eroded, then dilated, by a disc of `radius` pixels (its edge repeated): every patch brighter than its surroundings and narrower
    /// than the disc comes down to them; wider light stays.
    private static func opened(_ image: CIImage, radius: Double, region: CGRect) -> CIImage {
        let dilated = CIFilter.morphologyMaximum()
        dilated.inputImage = eroded(image, radius: radius, region: region).clampedToExtent()
        dilated.radius = Float(radius)
        return (dilated.outputImage ?? image).cropped(to: region)
    }

    /// The darkest of `image` within `radius` pixels, on each channel (its edge repeated).
    private static func eroded(_ image: CIImage, radius: Double, region: CGRect) -> CIImage {
        let filter = CIFilter.morphologyMinimum()
        filter.inputImage = image.clampedToExtent()
        filter.radius = Float(radius)
        return (filter.outputImage ?? image).cropped(to: region)
    }

    /// min(a, b) on every channel: a − max(0, a − b).
    private static func smaller(_ first: CIImage, _ second: CIImage) -> CIImage {
        SkinImageMath.positiveDifference(first, SkinImageMath.positiveDifference(first, second))
    }

    private static func maximum(_ image: CIImage) -> CIImage {
        let filter = CIFilter.maximumComponent()
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    private static func minimum(_ image: CIImage) -> CIImage {
        let filter = CIFilter.minimumComponent()
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}
