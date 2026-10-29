//
//  SkinBeautyFilter.swift
//  Cue Studio
//

import CoreImage

/// Today's smoothing (`ReadingVersion.skin` 2) on one face, with Core Image's own filters: an edge-aware smoothing of the skin that can go from a light
/// evening of pores to a clearly retouched skin, with the skin's finest grain laid back so it never turns to plastic unless asked.
///
/// 1. **Skin only.** Where to work is the face's mask (`SkinMask`: no eyes, brows or lips) times the gate on the face's own skin tone
///    (`SkinSmoothingFilter.skinGate`), so the hair, the beard, the shadows and the background are not touched.
/// 2. **An edge-aware base** (`evened`, after the guided filter of He, Sun and Tang): within `baseSigma`, what departs from the local mean by less
///    than `edgeLevel` is evened to it, what departs by more (an edge, a fold, a nostril, the line of the lips) keeps its shape. The mean is the
///    skin's own (the brows, the beard and the hair beside it count for nothing), so no dark halo spreads from them into the skin, and the mean
///    stays where it was, so nothing is brightened or darkened.
/// 3. **Texture apart.** What the base took away is split at the scale of the skin's grain (`grainSigma`): the larger part (spots, unevenness, fine
///    lines) stays away; of the grain itself, `textureKept` comes back. Only what was taken comes back, so an edge the base kept is not sharpened twice.
/// 4. **Only so much.** The result goes over the picture at `strength` times the mask, so what is not skin keeps its pixels exactly.
///
/// Done on sRGB-encoded values (the scale the levels mean) inside the face's region, so a 4K frame costs the size of the face.
nonisolated enum SkinBeautyFilter {
    static func apply(to image: CIImage, face: SkinFace, smoothing: SkinSmoothing) -> CIImage {
        let strength = SkinBeautyCalibration.strength(smoothing.amount) * min(max(face.presence, 0), 1) * face.trust
        let region = face.region.intersection(image.extent)
        guard strength > 0.001, !region.isNull, region.width >= 8, region.height >= 8 else { return image }
        let original = image.cropped(to: region)
        let encoded = original.applyingFilter("CILinearToSRGBToneCurve")

        // 1. Where the skin is: the face's mask times its gate, a little softened.
        let skin = SkinImageMath.multiplied(face.mask.cropped(to: region), SkinSmoothingFilter.skinGate(of: encoded, tone: face.tone))
        let weight = SkinImageMath.blurred(skin, sigma: max(1, face.width * 0.004), region: region)

        // 2. The edge-aware base.
        let sigma = SkinBeautyCalibration.baseSigma(faceWidth: face.width, amount: smoothing.amount)
        let base = evened(
            encoded, weight: weight, sigma: sigma, level: SkinBeautyCalibration.edgeLevel(amount: smoothing.amount),
            noise: SkinBeautyCalibration.noiseLevel(face.tone.noise), region: region
        )

        // 3. What the base took away, and the skin's grain of it laid back.
        let removed = SkinImageMath.signedDifference(encoded, base)
        let grain = SkinImageMath.signedDifference(
            removed, SkinImageMath.blurred(removed, sigma: SkinBeautyCalibration.grainSigma(faceWidth: face.width), region: region)
        )
        let kept = SkinBeautyCalibration.textureKept(smoothing.texture)
        let smoothed = SkinImageMath.sum(base, SkinImageMath.scaled(grain, by: kept))

        // 4. Over the picture, as much as the dial says, where the skin is.
        let amount = SkinImageMath.scaled(weight, by: strength)
        let result = SkinImageMath.mixed(smoothed.applyingFilter("CISRGBToneCurveToLinear"), over: original, mask: amount).cropped(to: region)
        return result.composited(over: image)
    }

    /// `image` evened toward its local mean where it departs from it by little, and kept where it departs by much: the mean `m` is a Gaussian of
    /// `sigma` over the skin (`weight`); the departure `d = I − m`, its brightness squared and averaged over half that, is `v` (everything counts
    /// there, so the skin at a brow's edge, and the edge itself, keep their departure); each pixel keeps `a = v / (v + ε)` of its departure
    /// (`m + a·d`), as a guided filter would, with `ε = (level · brightness of m)² + noise²`.
    /// Measured from the local mean, a gradient of light across the face (which the mean follows) is not an edge; measured against the
    /// brightness there, the shadow side of a face and dark skin are evened like the rest. The departures are small numbers, so their squares
    /// keep their precision in half floats.
    static func evened(_ image: CIImage, weight: CIImage, sigma: Double, level: Double, noise: Double, region: CGRect) -> CIImage {
        let mean = SkinSmoothingFilter.maskedBlur(of: image, weight: weight, sigma: sigma, region: region)
        let departure = SkinImageMath.signedDifference(image, mean)
        let brightness = SkinImageMath.luma(departure)
        let energy = SkinImageMath.blurred(SkinImageMath.multiplied(brightness, brightness), sigma: max(1, sigma / 2), region: region)
        let threshold = SkinImageMath.polynomial(SkinImageMath.luma(mean), [noise * noise, 0, level * level, 0])
        let kept = SkinImageMath.quotient(energy, SkinImageMath.sum(energy, threshold))
        return SkinImageMath.sum(mean, SkinImageMath.multiplied(kept, departure))
    }
}
