//
//  PersonMasker.swift
//  Cue Studio
//

import CoreImage
import os
import Vision

/// Finds the person in a frame with Vision, on the iPhone: a mask, white where the person is,
/// the size of the frame. The last masks are kept (a bounded cache), so scrubbing back over the
/// same moments doesn't ask again. Used on the compositor's queue only.
nonisolated final class PersonMasker: @unchecked Sendable {
    /// Masks kept at once (a few seconds of video).
    static let cacheLimit = 90

    private static let logger = Logger(subsystem: "studio.cue", category: "Background")
    /// The reasons already logged: a failing frame fails again on every frame after it, so each reason is said once.
    private static let logged = OSAllocatedUnfairLock<Set<String>>(initialState: [])

    private let cache = NSCache<NSString, CIImage>()
    private let request: VNGeneratePersonSegmentationRequest

    /// `quality`: the edit's preview and export use `.balanced`, so both look the same; the camera's
    /// live preview uses `.fast` to keep up.
    init(quality: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced) {
        cache.countLimit = Self.cacheLimit
        request = Self.makeRequest(quality: quality)
    }

    /// The person in `image`, asked every time (the camera's frames never come back).
    func mask(for image: CIImage) -> CIImage? {
        Self.mask(for: image, using: request)
    }

    /// The person in `image` (origin at zero), from the cache when `key` was asked before; nil when
    /// Vision can't tell.
    func mask(for image: CIImage, key: String) -> CIImage? {
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard let mask = Self.mask(for: image, using: request) else { return nil }
        cache.setObject(mask, forKey: key as NSString)
        return mask
    }

    /// The person in `image` with a request of its own (the cover, the support check).
    static func mask(for image: CIImage) -> CIImage? {
        mask(for: image, using: makeRequest())
    }

    private static func makeRequest(quality: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced) -> VNGeneratePersonSegmentationRequest {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = quality
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }

    private static func mask(for image: CIImage, using request: VNGeneratePersonSegmentationRequest) -> CIImage? {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            logOnce("Vision couldn't find the person in a \(Int(extent.width))×\(Int(extent.height)) frame: \(error)")
            return nil
        }
        guard let buffer = request.results?.first?.pixelBuffer else {
            logOnce("Vision gave no mask for a \(Int(extent.width))×\(Int(extent.height)) frame")
            return nil
        }
        let mask = CIImage(cvPixelBuffer: buffer)
        let scaleX = extent.width / mask.extent.width, scaleY = extent.height / mask.extent.height
        return mask
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// Without a mask the background effect leaves the frame as it is, which shows as "nothing happens": the Console says why.
    private static func logOnce(_ reason: String) {
        guard logged.withLock({ $0.insert(reason).inserted }) else { return }
        logger.error("\(reason, privacy: .public)")
    }
}
