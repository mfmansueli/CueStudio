//
//  FaceDetecting.swift
//  Cue Studio
//

import CoreImage

/// Finds the faces in a frame. The real one is Vision's (`VisionFaceDetector`); tests give it faces of their own, since a drawing is not a face to Vision.
nonisolated protocol FaceDetecting: Sendable {
    /// The faces in `image` (its origin at zero), the largest first.
    func faces(in image: CIImage) -> [FaceLandmarks]
}
