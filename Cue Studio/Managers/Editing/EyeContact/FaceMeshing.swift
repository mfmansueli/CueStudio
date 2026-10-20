//
//  FaceMeshing.swift
//  Cue Studio
//

import CoreVideo
import Foundation

/// Places a face's landmarks in a 256 × 256 crop of it (`FaceRegion`): MediaPipe's face mesh, 478 points with both irises.
nonisolated protocol FaceMeshing: Sendable {
    /// The landmarks in `crop` (a 256 × 256 BGRA buffer), in its pixels, and how sure the model is that there's a face (0 to 1);
    /// nil when the model can't run.
    func mesh(in crop: CVPixelBuffer) -> FaceMesh?
}
