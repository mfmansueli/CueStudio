//
//  FrameLook.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Auto, Adjust and Filters on a frame, with Core Image, in this order and each on its own:
/// 1. **Auto**, what was measured on the clip (`AutoCorrection`), at the intensity picked;
/// 2. **Adjust**, the creator's dials (`FrameLook+Adjust`: exposure, white balance, highlights and
///    shadows, contrast, saturation, vibrance, sharpness), read the way the edit was saved
///    (`LookSettings.version`: `FrameLook+Legacy` for the first reading);
/// 3. the **filter**, mixed in at its intensity (`FrameLook+Filters`).
///
/// The preview, the export, the cover and the filter thumbnails all go through here, with the look
/// of the stretch they draw: the take's, or the take's with a clip's overrides (`LookSettings`).
/// Zero is neutral at every step: a frame with nothing set comes back untouched.
nonisolated enum FrameLook {
    /// The take's own look on `image`.
    static func apply(_ edit: TakeEdit, to image: CIImage) -> CIImage {
        apply(LookSettings(edit), to: image)
    }

    static func apply(_ look: LookSettings, to image: CIImage) -> CIImage {
        var output = image
        if let auto = look.auto, look.autoAmount > 0 {
            output = AutoCorrectionRenderer.apply(auto.scaled(by: look.autoAmount), to: output)
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
