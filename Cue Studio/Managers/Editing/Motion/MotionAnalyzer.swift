//
//  MotionAnalyzer.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import Vision

/// Analyzes a recording with Vision, on the iPhone: each frame (up to 30 a second) is drawn upright on a small copy
/// (`side` points on its long side: framing and shake don't need a 4K frame); the camera's movement since the frame before is
/// measured on a grid of background tiles (`BackgroundTiles`), each registered on its own and combined by what most agree on
/// (`CameraMotion`), and, ten times a second, the copy is searched for faces and bodies. Reads the file once, start to end, and
/// can stop and go on later from where it stopped.
nonisolated final class MotionAnalyzer: MotionAnalyzing, @unchecked Sendable {
    enum AnalysisError: Error { case noVideo, unreadable }

    /// Long side of the copy every frame is analyzed on, in pixels.
    static let side: CGFloat = 512
    /// Least seconds of video between two checkpoints; a long video saves every twentieth of its length (each save writes
    /// the whole analysis so far).
    private let checkpointInterval: TimeInterval
    private let context = CIContext(options: [.cacheIntermediates: false, .name: "studio.cue.motion"])

    init(checkpointInterval: TimeInterval = 5) {
        self.checkpointInterval = checkpointInterval
    }

    @concurrent
    func analyze(
        videoAt url: URL, continuing previous: MotionAnalysis?, shouldStop: @escaping @Sendable () -> Bool,
        checkpoint: @escaping @Sendable (MotionAnalysis) -> Void
    ) async throws -> MotionAnalysis {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw AnalysisError.noVideo }
        let (naturalSize, transform, nominalRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let duration = try await asset.load(.duration).seconds
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let size = CGSize(width: abs(upright.width), height: abs(upright.height))
        var analysis = MotionAnalysis(duration: duration, width: size.width, height: size.height)
        analysis.frameRate = nominalRate > 0 ? Double(nominalRate) : nil
        if let previous, previous.isCurrent, abs(previous.duration - duration) < 0.05, previous.width == size.width, previous.height == size.height {
            analysis = previous
        }
        guard !analysis.isComplete, size.width > 0, size.height > 0 else {
            analysis.analyzedUntil = max(analysis.analyzedUntil, duration)
            return analysis
        }
        return try await read(
            asset: asset, track: track, transform: transform, uprightSize: size, into: analysis, shouldStop: shouldStop, checkpoint: checkpoint
        )
    }

    // MARK: - Reading

    private func read(
        asset: AVURLAsset, track: AVAssetTrack, transform: CGAffineTransform, uprightSize: CGSize, into start: MotionAnalysis,
        shouldStop: @Sendable () -> Bool, checkpoint: @Sendable (MotionAnalysis) -> Void
    ) async throws -> MotionAnalysis {
        var analysis = start
        let resumeAt = analysis.analyzedUntil
        // A little before where it stopped, so the first frame measured has the one before it.
        let readFrom = max(0, resumeAt - 0.2)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: readFrom, preferredTimescale: 600), end: CMTime(seconds: analysis.duration + 1, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }

        let scale = min(1, Self.side / max(uprightSize.width, uprightSize.height))
        let small = CGSize(width: (uprightSize.width * scale).rounded(), height: (uprightSize.height * scale).rounded())
        guard var current = Self.makeBuffer(small), var previous = Self.makeBuffer(small) else { throw AnalysisError.unreadable }
        var hasPrevious = false
        var lastSubject: SubjectSample?
        var lastFrame = -Double.infinity
        var nextSubject = analysis.subjects.last.map { $0.time + MotionAnalysis.subjectInterval } ?? 0
        let interval = max(checkpointInterval, analysis.duration / 20)
        var nextCheckpoint = resumeAt + interval
        let faces = VNDetectFaceRectanglesRequest()
        let bodies = VNDetectHumanRectanglesRequest()
        bodies.upperBodyOnly = false

        while let ready = try await provider.next() {
            if shouldStop() { return analysis }
            let time = ready.withUnsafeSampleBuffer { $0.presentationTimeStamp.seconds }
            // Up to 30 frames a second.
            guard time.isFinite, time >= lastFrame + 1 / MotionAnalysis.shiftRate - 0.002 else { continue }
            lastFrame = time
            let drawn = ready.withUnsafeSampleBuffer { sample -> Bool in
                guard let pixels = sample.imageBuffer else { return false }
                autoreleasepool { draw(pixels, transform: transform, scale: scale, into: current) }
                return true
            }
            guard drawn else { continue }
            autoreleasepool {
                let tiles = BackgroundTiles.tiles(around: lastSubject ?? analysis.subjects.last, aspect: Double(small.width / small.height))
                if hasPrevious, time > resumeAt + 0.000_1, let shift = Self.shift(from: previous, to: current, on: tiles) {
                    analysis.shifts.append(FrameShift(
                        time: time, dx: shift.dx / Double(small.width), dy: shift.dy / Double(small.height), angle: shift.angle
                    ))
                }
                if time >= nextSubject - 0.001, time >= resumeAt {
                    let found = subjects(in: current, at: time, faces: faces, bodies: bodies)
                    analysis.subjects.append(found)
                    lastSubject = found
                    nextSubject = max(nextSubject + MotionAnalysis.subjectInterval, time + MotionAnalysis.subjectInterval * 0.5)
                }
            }
            swap(&current, &previous)
            hasPrevious = true
            analysis.analyzedUntil = max(analysis.analyzedUntil, time)
            if time >= nextCheckpoint {
                checkpoint(analysis)
                nextCheckpoint = time + interval
            }
        }
        analysis.analyzedUntil = analysis.duration
        return analysis
    }

    /// The frame upright and reduced into `buffer`.
    private func draw(_ pixels: CVPixelBuffer, transform: CGAffineTransform, scale: CGFloat, into buffer: CVPixelBuffer) {
        var image = CIImage(cvPixelBuffer: pixels)
            .transformed(by: FramePipeline.uprightTransform(transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(pixels))))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        context.render(image, to: buffer)
    }

    /// Faces and bodies in the frame, on the top-left unit square.
    private func subjects(
        in buffer: CVPixelBuffer, at time: TimeInterval, faces: VNDetectFaceRectanglesRequest, bodies: VNDetectHumanRectanglesRequest
    ) -> SubjectSample {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        try? handler.perform([faces, bodies])
        let found = (faces.results ?? []).filter { $0.confidence > 0.5 }.map { NormalizedBox.fromVision($0.boundingBox) }
        let people = (bodies.results ?? []).filter { $0.confidence > 0.3 }.map { NormalizedBox.fromVision($0.boundingBox) }
        return SubjectSample(time: time, faces: found, bodies: people)
    }

    /// How the camera moved from `previous` to `current`, in pixels of the copy (right and down positive) and radians (clockwise
    /// positive), from the slide of each tile in `tiles`; nil when no tile could be registered (a black frame, a cut).
    static func shift(from previous: CVPixelBuffer, to current: CVPixelBuffer, on tiles: [NormalizedBox]) -> (dx: Double, dy: Double, angle: Double)? {
        CVPixelBufferLockBaseAddress(previous, .readOnly)
        CVPixelBufferLockBaseAddress(current, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(current, .readOnly)
            CVPixelBufferUnlockBaseAddress(previous, .readOnly)
        }
        let width = Double(CVPixelBufferGetWidth(current)), height = Double(CVPixelBufferGetHeight(current))
        var measured: [CameraMotion.Tile] = []
        for tile in tiles {
            let rect = CGRect(x: tile.x * width, y: tile.y * height, width: tile.width * width, height: tile.height * height).integral
            // A flat tile (sky, a wall) can't be registered: what Vision says about it is noise.
            guard rect.width >= 24, rect.height >= 24, texture(of: current, in: rect) >= minimumTexture,
                  let before = view(of: previous, rect), let after = view(of: current, rect),
                  let slide = slide(from: before, to: after),
                  // More than a quarter of the tile in one frame is a registration that failed, not the camera.
                  abs(slide.dx) < rect.width / 4, abs(slide.dy) < rect.height / 4 else { continue }
            measured.append(CameraMotion.Tile(x: rect.midX - width / 2, y: rect.midY - height / 2, dx: slide.dx, dy: slide.dy))
        }
        return CameraMotion.estimate(measured)
    }

    /// Least spread of a tile's brightness (0 to 255) for it to be measured.
    static let minimumTexture = 8.0

    /// How much a tile's brightness varies (the standard deviation of its green, every other pixel); the buffer is locked.
    private static func texture(of buffer: CVPixelBuffer, in rect: CGRect) -> Double {
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var sum = 0.0, squares = 0.0, count = 0.0
        for row in Swift.stride(from: Int(rect.minY), to: Int(rect.maxY), by: 2) {
            for column in Swift.stride(from: Int(rect.minX), to: Int(rect.maxX), by: 2) {
                // BGRA: green is the second byte.
                let green = Double(pixels[row * stride + column * 4 + 1])
                sum += green
                squares += green * green
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        let mean = sum / count
        return sqrt(max(0, squares / count - mean * mean))
    }

    /// How the picture of one tile slid, in pixels (right and down positive). The previous frame is the reference; the current
    /// one is registered onto it, so the transform found is the opposite of how the picture moved.
    private static func slide(from previous: CVPixelBuffer, to current: CVPixelBuffer) -> (dx: Double, dy: Double)? {
        let handler = VNImageRequestHandler(cvPixelBuffer: previous, options: [:])
        let request = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: current, options: [:])
        guard (try? handler.perform([request])) != nil, let result = request.results?.first else { return nil }
        let move = result.alignmentTransform
        // Vision's y goes up.
        return (Double(-move.tx), Double(move.ty))
    }

    /// A buffer over part of `buffer`'s pixels (top-left `rect`), without copying them; `buffer` must stay locked while it's used.
    private static func view(of buffer: CVPixelBuffer, _ rect: CGRect) -> CVPixelBuffer? {
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let start = base + Int(rect.minY) * stride + Int(rect.minX) * 4
        var view: CVPixelBuffer?
        CVPixelBufferCreateWithBytes(
            nil, Int(rect.width), Int(rect.height), kCVPixelFormatType_32BGRA, start, stride, nil, nil, nil, &view
        )
        return view
    }

    private static func makeBuffer(_ size: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        return buffer
    }
}
