//
//  CutoutChecker.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import Vision

/// Check the cutout, with Vision on the iPhone: reads the stretch of the recording start to end, up to `frameRate` frames a second,
/// upright, asks for the person in each (the same request and quality as the edit's frames) and steadies the masks as the edit does
/// (`PersonMaskTrack`); the frames past the hold are the failures. The recording as filmed, before the edit's crop: the crop changes
/// little of what Vision sees.
nonisolated struct CutoutChecker: CutoutChecking {
    /// Frames read a second: the hold and the fade are measured in time, so fewer frames than the video has find the same moments.
    static let frameRate: Double = 15

    @concurrent
    func check(videoAt url: URL, over span: TimeSpan, progress: @escaping @Sendable (Double) -> Void) async throws -> CutoutCheckResult {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw CocoaError(.fileReadCorruptFile) }
        let transform = try await track.load(.preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: max(0, span.start), preferredTimescale: 600), end: CMTime(seconds: span.end, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }

        let request = PersonMasker.makeRequest()
        var masks = PersonMaskTrack()
        var result = CutoutCheckResult()
        var failing: [TimeInterval] = []
        var lastRead = -Double.infinity
        let interval = 1 / Self.frameRate
        while let ready = try await provider.next() {
            try Task.checkCancellation()
            let time = ready.withUnsafeSampleBuffer { $0.presentationTimeStamp.seconds }
            guard time.isFinite, time >= lastRead + interval - 0.002 else { continue }
            lastRead = time
            let raw = ready.withUnsafeSampleBuffer { sample -> PersonMaskFrame? in
                guard let pixels = sample.imageBuffer else { return nil }
                return autoreleasepool { () -> PersonMaskFrame? in
                    let image = FramePipeline.upright(pixels, transform: transform)
                    return PersonMasker.frame(for: image, using: request)
                }
            }
            let step = masks.next(raw, at: time, epoch: span.start)
            result.frames += 1
            if step.state == .held { result.heldFrames += 1 }
            if step.state.isFailure { failing.append(time) }
            progress(min(1, max(0, (time - span.start) / max(0.001, span.duration))))
        }
        result.failures = CutoutCheckResult.moments(of: failing, interval: interval)
        progress(1)
        return result
    }
}
