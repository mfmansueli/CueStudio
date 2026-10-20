//
//  FaceMesh.swift
//  Cue Studio
//

import Foundation

/// What `FaceMeshing` found in one crop.
nonisolated struct FaceMesh: Sendable {
    /// 478 points in the crop's pixels (MediaPipe's face mesh order; 468–477 the irises).
    var points: [SIMD2<Double>]
    /// How sure the model is there's a face, 0 to 1.
    var score: Double

    static let count = 478
    /// The face mesh's indices of each eye's outline in `EyeShape.contour`'s order, the eye that's on the image's left in an
    /// unmirrored face first, then its iris (centre, then four points on its edge).
    static let firstEye = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
    static let secondEye = [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
    static let firstIris = Array(468...472)
    static let secondIris = Array(473...477)
}
