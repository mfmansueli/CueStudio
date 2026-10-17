//
//  ObjectTracker.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import Vision

/// Track with Vision, on the iPhone: each frame of the recording (up to 30 a second) is drawn upright on a small copy and the
/// object is followed from frame to frame (`VNTrackObjectRequest`, accurate). Backwards, the recording is read a second at a
/// time from the end and each second is followed in reverse, so only a second of small frames is ever held. The object is
/// lost when Vision is no longer sure of it (it left the frame or was covered).
nonisolated final class ObjectTracker: ObjectTracking, @unchecked Sendable {
    enum TrackError: Error { case noVideo, unreadable }

    /// Long side of the frames followed, in pixels.
    static let side: CGFloat = 640
    /// Below this, the object is lost.
    static let lostBelow: Float = 0.3

    private let context = CIContext(options: [.cacheIntermediates: false, .name: "studio.cue.tracking"])

    @concurrent
    func track(
        videoAt url: URL, box: NormalizedBox, at time: TimeInterval, until: TimeInterval, progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TrackSample] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw TrackError.noVideo }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let duration = try await asset.load(.duration).seconds
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let size = CGSize(width: abs(upright.width), height: abs(upright.height))
        let scale = min(1, Self.side / max(size.width, size.height))
        let small = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let frames = Frames(asset: asset, track: track, transform: transform, scale: scale, size: small, context: context)
        let end = min(max(0, until), duration)
        let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: box.visionRect))
        request.trackingLevel = .accurate
        let handler = VNSequenceRequestHandler()
        var samples = [TrackSample(time: time, box: box, confidence: 1)]
        let total = max(0.001, abs(end - time))
        // One step: the object followed onto `buffer`; false when it's lost.
        func follow(_ buffer: CVPixelBuffer, at moment: TimeInterval) -> Bool {
            guard (try? handler.perform([request], on: buffer)) != nil,
                  let found = request.results?.first as? VNDetectedObjectObservation, found.confidence >= Self.lostBelow
            else { return false }
            request.inputObservation = found
            samples.append(TrackSample(time: moment, box: .fromVision(found.boundingBox), confidence: Double(found.confidence)))
            progress(min(1, abs(moment - time) / total))
            return true
        }
        if end >= time {
            try await frames.read(from: time, to: end) { buffer, moment in
                try Task.checkCancellation()
                return moment <= time + 0.000_1 || follow(buffer, at: moment)
            }
        } else {
            var chunkEnd = time
            var lost = false
            while chunkEnd > end + 0.000_1, !lost {
                let chunkStart = max(end, chunkEnd - 1)
                var chunk: [(CVPixelBuffer, TimeInterval)] = []
                try await frames.read(from: chunkStart, to: chunkEnd) { buffer, moment in
                    try Task.checkCancellation()
                    if moment < chunkEnd - 0.000_1, let copy = Self.copy(buffer) { chunk.append((copy, moment)) }
                    return true
                }
                for (buffer, moment) in chunk.reversed() where !lost {
                    lost = !follow(buffer, at: moment)
                }
                chunkEnd = chunkStart
            }
        }
        return samples.sorted { $0.time < $1.time }
    }

    private static func copy(_ buffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard let made = Frames.makeBuffer(CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))) else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        CVPixelBufferLockBaseAddress(made, [])
        defer {
            CVPixelBufferUnlockBaseAddress(made, [])
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        guard let from = CVPixelBufferGetBaseAddress(buffer), let into = CVPixelBufferGetBaseAddress(made) else { return nil }
        let rows = CVPixelBufferGetHeight(buffer)
        let fromStride = CVPixelBufferGetBytesPerRow(buffer), intoStride = CVPixelBufferGetBytesPerRow(made)
        for row in 0..<rows {
            memcpy(into + row * intoStride, from + row * fromStride, min(fromStride, intoStride))
        }
        return made
    }

    /// A recording's frames between two moments, each drawn upright and reduced into one buffer (up to 30 a second).
    private struct Frames {
        let asset: AVURLAsset
        let track: AVAssetTrack
        let transform: CGAffineTransform
        let scale: CGFloat
        let size: CGSize
        let context: CIContext

        /// Hands each frame from `start` to `end` to `body` (the buffer is reused for the next one), until `body` says stop.
        func read(from start: TimeInterval, to end: TimeInterval, _ body: (CVPixelBuffer, TimeInterval) throws -> Bool) async throws {
            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = CMTimeRange(
                start: CMTime(seconds: max(0, start), preferredTimescale: 600), end: CMTime(seconds: end + 0.001, preferredTimescale: 600)
            )
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            ])
            let provider = reader.outputProvider(for: output)
            try reader.start()
            defer { reader.cancelReading() }
            guard let buffer = Self.makeBuffer(size) else { throw TrackError.unreadable }
            var last = -Double.infinity
            while let ready = try await provider.next() {
                let moment = ready.withUnsafeSampleBuffer { $0.presentationTimeStamp.seconds }
                guard moment.isFinite, moment >= start - 0.000_1, moment >= last + 1 / 30.0 - 0.002 else { continue }
                if moment > end + 0.000_1 { break }
                last = moment
                let drawn = ready.withUnsafeSampleBuffer { sample -> Bool in
                    guard let pixels = sample.imageBuffer else { return false }
                    autoreleasepool {
                        var image = CIImage(cvPixelBuffer: pixels).transformed(
                            by: CueVideoCompositor.uprightTransform(transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(pixels)))
                        )
                        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
                            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        context.render(image, to: buffer)
                    }
                    return true
                }
                guard drawn else { continue }
                let goesOn = try autoreleasepool { try body(buffer, moment) }
                if !goesOn { break }
            }
        }

        static func makeBuffer(_ size: CGSize) -> CVPixelBuffer? {
            var buffer: CVPixelBuffer?
            let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
            CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
            return buffer
        }
    }
}
