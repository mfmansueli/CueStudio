//
//  SkinSmoothingPass.swift
//  Cue Studio
//

import CoreImage

/// What `SkinSmoother` found in one frame: the faces to smooth, ready to be drawn at any amount. It is made on the frame as recorded (before the
/// background effect, so a face in a photo put behind the creator is not smoothed) and applied by `FrameLook` after Auto, whatever the amount of the clip
/// that plays. A frame with no face, or no skin tone to trust, has an empty pass and comes back untouched.
nonisolated struct SkinSmoothingPass {
    let faces: [SkinFace]

    static let none = SkinSmoothingPass(faces: [])

    /// `image` with the skin of every face smoothed by `value` (0 to 100); `image` itself at 0.
    func apply(value: Double, to image: CIImage) -> CIImage {
        guard SkinSmoothingCalibration.isOn(value) else { return image }
        return faces.reduce(image) { SkinSmoothingFilter.apply(to: $0, face: $1, value: value) }
    }
}
