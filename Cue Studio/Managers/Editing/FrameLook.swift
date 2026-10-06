//
//  FrameLook.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Auto, Skin Smoothing, Adjust and Filters on a frame, with Core Image, in this order and each on its own:
/// 1. **Auto**, what was measured on the clip (`AutoCorrection`), at the intensity picked;
/// 2. **Skin Smoothing**, the faces' skin softened (`SkinSmoothingFilter`), before the dials and the filter on purpose: it reads the picture's
///    own tones, so the dials' contrast and the filter's grade don't move what counts as skin or as texture, a filter's grain is not smoothed
///    away, and the Sharpness dial, which comes after, still sharpens what is left. The faces come with the frame (`SkinSmoothingPass`); without
///    one, or at 0, this step does nothing;
/// 3. **Adjust**, the creator's dials (`FrameLook+Adjust`: exposure, white balance, highlights and
///    shadows, contrast, saturation, vibrance, sharpness), read the way the edit was saved
///    (`LookSettings.version`: `FrameLook+Legacy` for the first reading);
/// 4. the **filter**, mixed in at its intensity (`FrameLook+Filters`).
///
/// Texts and captions are drawn over all of this afterwards (`CueVideoCompositor`), so they are never smoothed.
///
/// The preview, the export, the cover and the filter thumbnails all go through here, with the look
/// of the stretch they draw: the take's, or the take's with a clip's overrides (`LookSettings`).
/// Zero is neutral at every step: a frame with nothing set comes back untouched.
nonisolated enum FrameLook {
    /// The take's own look on `image`.
    static func apply(_ edit: TakeEdit, to image: CIImage) -> CIImage {
        apply(LookSettings(edit), to: image)
    }

    static func apply(_ look: LookSettings, to image: CIImage, skin: SkinSmoothingPass? = nil) -> CIImage {
        var output = image
        if let auto = look.auto, look.autoAmount > 0 {
            output = AutoCorrectionRenderer.apply(auto.scaled(by: look.autoAmount), to: output)
        }
        if let skin, SkinSmoothingCalibration.isOn(look.skinSmoothing) {
            output = skin.apply(value: look.skinSmoothing, to: output)
        }
        output = look.version >= 2 ? adjusted(look, output) : adjustedWithFirstReading(look, output)
        return filtered(look, output)
    }

    /// The first reading of the dials, then what came later (vibrance and tint), which has only one.
    private static func adjustedWithFirstReading(_ look: LookSettings, _ image: CIImage) -> CIImage {
        let output = adjustedLegacy(look, image)
        return vibrance(look.vibrance, on: whiteBalanceTint(look.tint, on: output))
    }
}
