//
//  VisionFaceDetector.swift
//  Cue Studio
//

import CoreImage
import Vision

/// Faces and their landmarks with Vision, on the iPhone, on a copy of the frame no bigger than `SkinSmoothingCalibration.detectionSide`: finding a face
/// doesn't need the pixels of a 4K frame. Faces that are too small to matter (people far behind the creator) are dropped, and no more than
/// `maximumFaces` are kept, the largest first. A frame Vision can't read has no faces.
nonisolated final class VisionFaceDetector: FaceDetecting, @unchecked Sendable {
    /// One request, kept for every frame (its results are read right after each use, under the lock), so nothing is made per frame.
    private let request = VNDetectFaceLandmarksRequest()
    private let lock = NSLock()

    func faces(in image: CIImage) -> [FaceLandmarks] {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return [] }
        // A picture already reduced and held in a pixel buffer (what `SkinSmoother` hands over) goes to Vision as it is; any other is reduced here.
        let scale = min(1, SkinSmoothingCalibration.detectionSide / max(extent.width, extent.height))
        let small = scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image
        let size = small.extent.size
        lock.lock()
        defer { lock.unlock() }
        // The handler and what Vision makes for one frame go with it (it runs on every frame of an export).
        let performed: Bool = autoreleasepool {
            let handler = small.pixelBuffer.map { VNImageRequestHandler(cvPixelBuffer: $0, options: [:]) }
                ?? VNImageRequestHandler(ciImage: small, options: [:])
            return (try? handler.perform([request])) != nil
        }
        guard performed else { return [] }
        let shorterSide = min(size.width, size.height)
        let found = (request.results ?? [])
            .filter { $0.boundingBox.height * size.height >= SkinSmoothingCalibration.minimumFaceShare * shorterSide }
            .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
            .prefix(SkinSmoothingCalibration.maximumFaces)
        return found.compactMap { Self.landmarks(of: $0, in: size) }
    }

    /// The outlines of one observation in the frame's unit square; nil when Vision gave no landmarks or too few of them to draw a mask.
    private static func landmarks(of face: VNFaceObservation, in size: CGSize) -> FaceLandmarks? {
        guard let found = face.landmarks else { return nil }
        func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            region?.pointsInImage(imageSize: size).map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) } ?? []
        }
        let landmarks = FaceLandmarks(
            box: face.boundingBox, contour: points(found.faceContour), leftEye: points(found.leftEye), rightEye: points(found.rightEye),
            leftBrow: points(found.leftEyebrow), rightBrow: points(found.rightEyebrow),
            outerLips: points(found.outerLips), innerLips: points(found.innerLips)
        )
        return landmarks.isUsable ? landmarks : nil
    }
}
