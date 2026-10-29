//
//  SkinSmoothingPass.swift
//  Cue Studio
//

import CoreImage

/// What `SkinSmoother` found in one frame: the faces Skin works on, ready to be drawn with any of its settings. One look at the frame serves every
/// control (the smoothing, the face light, the shine): none of them finds faces of its own. It is made on the frame as recorded (before the background
/// effect, so a face in a photo put behind the creator is left alone) and applied by `FrameLook` after Auto, with the Skin of the clip that plays. A
/// frame with no face, or no skin tone to trust, has an empty pass and comes back untouched.
nonisolated struct SkinSmoothingPass {
    let faces: [SkinFace]

    static let none = SkinSmoothingPass(faces: [])

    /// `image` with `skin` on every face, in this order: the shine comes down on the skin as it was, the smoothing evens it (by the engine its
    /// numbers were made for: the first one's `SkinSmoothingFilter`, today's `SkinBeautyFilter`), then the face is lit. `image` itself with nothing on.
    func apply(_ skin: SkinLook, to image: CIImage) -> CIImage {
        guard skin.isOn else { return image }
        return faces.reduce(image) { image, face in
            var output = image
            if skin.antiShine > 0 { output = SkinShineFilter.apply(to: output, face: face, value: skin.antiShine) }
            if skin.smoothing.isOn {
                output = skin.smoothing.usesFirstEngine
                    ? SkinSmoothingFilter.apply(to: output, face: face, value: skin.smoothing.amount)
                    : SkinBeautyFilter.apply(to: output, face: face, smoothing: skin.smoothing)
            }
            if skin.faceLight > 0 { output = FaceLightFilter.apply(to: output, face: face, value: skin.faceLight) }
            return output
        }
    }
}
