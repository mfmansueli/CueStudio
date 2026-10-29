//
//  FaceLightFilter.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Skin's face light on one face: a soft light, like a reflector held in front of the creator, on the face only. Not the exposure: the rest of the
/// picture keeps its light, and the face's own lights and darks keep their places.
///
/// - **Where:** the face's whole outline (`SkinFace.faceMask`: the eyes and lips too, a light falls on all of the face), feathered widely so the light
///   fades into the hair and the neck with no edge.
/// - **How:** a gain on the three channels together (`1 + L·4m(1 − m)`, `m` the brightest channel, in encoded values), so the skin's hue and
///   saturation stay as they are (a light, not a wash of white). It is most in the middle tones and none at black or white: the pupils, the
///   nostrils and the shadows stay dark, and no channel goes past white (`maximumLight` < ¼ keeps the curve rising).
nonisolated enum FaceLightFilter {
    static func apply(to image: CIImage, face: SkinFace, value: Double) -> CIImage {
        let light = SkinBeautyCalibration.light(value) * min(max(face.presence, 0), 1) * face.trust
        // The light's soft edge reaches past the face: the region grows by the feather.
        let feather = face.width * SkinBeautyCalibration.lightFeather
        let region = face.region.insetBy(dx: -feather, dy: -feather).intersection(image.extent).integral
        guard light > 0.001, !region.isNull, region.width >= 8, region.height >= 8 else { return image }
        let original = image.cropped(to: region)
        let encoded = original.applyingFilter("CILinearToSRGBToneCurve")
        let brightest = CIFilter.maximumComponent()
        brightest.inputImage = encoded
        let weight = SkinImageMath.clamped(SkinImageMath.polynomial(brightest.outputImage ?? encoded, [0, 4, -4, 0]))
        let lit = SkinImageMath.multiplied(encoded, SkinImageMath.scaled(weight, by: light, plus: 1))
        // The mask covers the face's region; around it, black, so the feather fades to nothing.
        let outline = face.faceMask.composited(over: CIImage(color: .black).cropped(to: region))
        let pool = SkinImageMath.blurred(outline, sigma: feather / 2, region: region)
        let result = SkinImageMath.mixed(lit.applyingFilter("CISRGBToneCurveToLinear"), over: original, mask: pool).cropped(to: region)
        return result.composited(over: image)
    }
}
