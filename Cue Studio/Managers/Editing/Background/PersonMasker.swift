//
//  PersonMasker.swift
//  Cue Studio
//

import CoreImage
import os
import Vision

/// Finds the person in a frame with Vision, on the iPhone: a mask, white where the person is, the size of the frame. For the edit's
/// frames the masks are steadied in play order, one stretch of video at a time (`PersonMaskTrack`: a shimmering edge settles, a failed
/// frame keeps the last good outline for a moment), and the masks shown last are kept (a bounded cache), so a paused frame drawn again,
/// or scrubbing back over the same moments, shows what was shown. Used on the compositor's queue only.
nonisolated final class PersonMasker: @unchecked Sendable {
    /// Masks kept at once (a few seconds of video).
    static let cacheLimit = 90

    private static let logger = Logger(subsystem: "studio.cue", category: "Background")
    /// The reasons already logged: a failing frame fails again on every frame after it, so each reason is said once.
    private static let logged = OSAllocatedUnfairLock<Set<String>>(initialState: [])

    private let cache = NSCache<NSString, CIImage>()
    private let request: VNGeneratePersonSegmentationRequest
    /// One track for each stream of frames (the main side and the other side of a dissolve, of each background).
    private let tracks = OSAllocatedUnfairLock<[String: PersonMaskTrack]>(initialState: [:])

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

    /// The person in `image` (origin at zero) at `moment`, steadied on the frames of its stretch before it; from the cache when the
    /// moment was drawn before. Nil when there is no outline to show (Vision can't tell, and nothing good came before).
    func mask(for image: CIImage, at moment: PersonMaskMoment) -> CIImage? {
        if let cached = cache.object(forKey: moment.key as NSString) { return cached }
        let raw = Self.frame(for: image, using: request)
        let step = tracks.withLock { tracks in
            var track = tracks[moment.track] ?? PersonMaskTrack()
            defer { tracks[moment.track] = track }
            return track.next(raw, at: moment.time, epoch: moment.epoch)
        }
        guard let shown = step.mask else { return nil }
        let mask = shown.image(in: image.extent)
        cache.setObject(mask, forKey: moment.key as NSString)
        return mask
    }

    /// The person in `image` with a request of its own (the cover, the support check).
    static func mask(for image: CIImage) -> CIImage? {
        mask(for: image, using: makeRequest())
    }

    /// Vision's mask of `image` as bytes, at the size Vision made it; nil when it can't tell. `request` is used on one queue at a time.
    static func frame(for image: CIImage, using request: VNGeneratePersonSegmentationRequest) -> PersonMaskFrame? {
        buffer(for: image, using: request).flatMap(PersonMaskFrame.init(buffer:))
    }

    static func makeRequest(quality: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced) -> VNGeneratePersonSegmentationRequest {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = quality
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }

    private static func mask(for image: CIImage, using request: VNGeneratePersonSegmentationRequest) -> CIImage? {
        let extent = image.extent
        guard let buffer = buffer(for: image, using: request) else { return nil }
        let mask = CIImage(cvPixelBuffer: buffer)
        let scaleX = extent.width / mask.extent.width, scaleY = extent.height / mask.extent.height
        return mask
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    private static func buffer(for image: CIImage, using request: VNGeneratePersonSegmentationRequest) -> CVPixelBuffer? {
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
        return buffer
    }

    /// Without a mask the background effect leaves the frame as it is, which shows as "nothing happens": the Console says why.
    private static func logOnce(_ reason: String) {
        guard logged.withLock({ $0.insert(reason).inserted }) else { return }
        logger.error("\(reason, privacy: .public)")
    }
}
