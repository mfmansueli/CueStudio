//
//  FaceFinder.swift
//  Cue Studio
//

import AVFoundation
import CoreGraphics
import ImageIO
import Vision

/// `FaceFinding` with Vision, on the iPhone: one picture, read small (a face is found as well at 480 pixels).
nonisolated struct FaceFinder: FaceFinding {
    /// Long side of the picture searched.
    static let side: CGFloat = 480

    @concurrent
    func face(in url: URL, isVideo: Bool, at time: TimeInterval) async -> (box: CGRect?, size: CGSize)? {
        guard let image = isVideo ? await Self.frame(of: url, at: time) : Self.photo(at: url) else { return nil }
        let size = CGSize(width: image.width, height: image.height)
        return (Self.boxes(in: image).first, size)
    }

    @concurrent
    func faces(in url: URL, isVideo: Bool, at time: TimeInterval) async -> [CGRect]? {
        // The very frame: a face moving between nearby frames would be offered where it isn't.
        guard let image = isVideo ? await Self.frame(of: url, at: time, exactly: true) : Self.photo(at: url) else { return nil }
        return Self.boxes(in: image)
    }

    /// The faces Vision is sure of, largest first, from the top left.
    private static func boxes(in image: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? [])
            .filter { $0.confidence > 0.5 }
            .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
            // Vision's boxes are from the bottom left.
            .map { CGRect(x: $0.boundingBox.minX, y: 1 - $0.boundingBox.maxY, width: $0.boundingBox.width, height: $0.boundingBox.height) }
    }

    private static func frame(of url: URL, at time: TimeInterval, exactly: Bool = false) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: side, height: side)
        let tolerance = exactly ? .zero : CMTime(seconds: 0.2, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        return try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)).image
    }

    private static func photo(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
