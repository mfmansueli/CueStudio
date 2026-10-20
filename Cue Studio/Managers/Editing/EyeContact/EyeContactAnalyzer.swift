//
//  EyeContactAnalyzer.swift
//  Cue Studio
//

import AVFoundation
import ImageIO
import Vision

/// Finds the main person's eyes in every frame of a recording (up to 60 a second), on the iPhone: MediaPipe's face mesh in Core ML
/// (`FaceMeshModel`) places each eye's outline and iris in a crop of the face (`FaceRegion`, cut on the CPU by `FaceCrop`), and
/// follows the face from frame to frame by its own points. Vision looks for faces every few frames, to find the main person again and
/// to notice someone else in the picture. Nothing is drawn on the GPU, so it also works while an export runs in the background.
///
/// The main person is the largest face, followed while it stays (a face that appears beside them doesn't take over); a frame where
/// another face is nearly as large is marked crowded. Reads the stretch the preview shows first, then the rest, and can stop and go
/// on later from where it stopped.
nonisolated final class EyeContactAnalyzer: EyeContactAnalyzing, @unchecked Sendable {
    enum AnalysisError: Error { case noVideo }

    /// Most frames analyzed per second (a 120 fps video is read every other frame).
    static let mostFramesPerSecond = 60.0
    /// How much the preview's stretch reaches before and after the moment it shows, in seconds.
    static let focusBefore: TimeInterval = 2
    static let focusAfter: TimeInterval = 15
    /// Another face at least this share of the main one's width makes a frame crowded.
    static let crowdedShare = 0.6
    /// Faces are looked for in one frame of this many; in the others the face mesh follows the face by its own points. A frame
    /// where the mesh loses it looks for the face again.
    static let detectionEvery = 10
    /// The face mesh's score under which there's no face in its crop.
    static let leastFaceScore = 0.5

    /// Least seconds of video between two checkpoints; a long video saves every twentieth of its length.
    private let checkpointInterval: TimeInterval
    private let meshes: FaceMeshing

    init(checkpointInterval: TimeInterval = 5, meshes: FaceMeshing = FaceMeshModel.shared) {
        self.checkpointInterval = checkpointInterval
        self.meshes = meshes
    }

    @concurrent
    func analyze(
        videoAt url: URL, continuing previous: EyeContactAnalysis?, focus: TimeInterval?, shouldStop: @escaping @Sendable () -> Bool,
        checkpoint: @escaping @Sendable (EyeContactAnalysis) -> Void
    ) async throws -> EyeContactAnalysis {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw AnalysisError.noVideo }
        let (naturalSize, transform, nominalRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let duration = try await asset.load(.duration).seconds
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let size = CGSize(width: abs(upright.width), height: abs(upright.height))
        let stamp = EyeContactAnalysisStore.fileStamp(of: url)
        var analysis = EyeContactAnalysis(duration: duration, width: size.width, height: size.height, fileStamp: stamp)
        analysis.frameRate = nominalRate > 0 ? Double(nominalRate) : nil
        if let previous, previous.isCurrent(forFile: stamp), abs(previous.duration - duration) < 0.05,
           previous.width == size.width, previous.height == size.height {
            analysis = previous
        }
        guard size.width > 0, size.height > 0 else { return analysis }
        let uprightFromBuffer = transform.concatenating(CGAffineTransform(translationX: -upright.minX, y: -upright.minY))
        let pass = Pass(
            asset: asset, track: track, orientation: Self.orientation(of: transform), size: size, uprightFromBuffer: uprightFromBuffer,
            interval: max(checkpointInterval, analysis.duration / 20), shouldStop: shouldStop, checkpoint: checkpoint
        )
        for span in Self.order(analysis, focus: focus) where try await read(span, with: pass, into: &analysis) {
            // Stopped: what was read is kept.
            return analysis
        }
        return analysis
    }

    /// What reading every stretch of one recording shares.
    private struct Pass {
        let asset: AVURLAsset
        let track: AVAssetTrack
        let orientation: CGImagePropertyOrientation
        let size: CGSize
        /// The frame's buffer pixels → upright pixels.
        let uprightFromBuffer: CGAffineTransform
        /// Seconds of video between two checkpoints.
        let interval: TimeInterval
        let shouldStop: @Sendable () -> Bool
        let checkpoint: @Sendable (EyeContactAnalysis) -> Void
    }

    /// The stretches still to read, in the order they're read: from just before `focus` on for a while, then on to the end, then
    /// from the start.
    static func order(_ analysis: EyeContactAnalysis, focus: TimeInterval?) -> [TimeSpan] {
        let whole = TimeSpan(start: 0, end: analysis.duration)
        guard let focus else { return analysis.missing(in: whole) }
        let start = min(max(0, focus - focusBefore), analysis.duration)
        let near = TimeSpan(start: start, end: min(analysis.duration, focus + focusAfter))
        let later = TimeSpan(start: near.end, end: analysis.duration)
        let earlier = TimeSpan(start: 0, end: start)
        return analysis.missing(in: near) + analysis.missing(in: later) + analysis.missing(in: earlier)
    }

    // MARK: - Reading

    /// Reads `span`'s frames into `analysis`. Returns true when it stopped because `shouldStop` said so (what was read is kept).
    private func read(_ span: TimeSpan, with pass: Pass, into analysis: inout EyeContactAnalysis) async throws -> Bool {
        let reader = try AVAssetReader(asset: pass.asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: span.start, preferredTimescale: 600), end: CMTime(seconds: span.end, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(track: pass.track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        defer { reader.cancelReading() }

        var tracker = Tracker(meshes: meshes, pass: pass)
        var found: [EyeSample] = []
        var lastFrame = -Double.infinity
        var from = span.start
        var nextCheckpoint = span.start + pass.interval
        let frameLength = 1 / max(1, analysis.frameRate ?? 30)
        while let ready = try await provider.next() {
            if pass.shouldStop() {
                if lastFrame.isFinite { analysis.add(found, over: TimeSpan(start: from, end: min(span.end, lastFrame + frameLength))) }
                return true
            }
            let time = ready.withUnsafeSampleBuffer { $0.presentationTimeStamp.seconds }
            guard time.isFinite, time >= span.start - 0.001, time < span.end,
                  time >= lastFrame + 1 / Self.mostFramesPerSecond - 0.002 else { continue }
            lastFrame = time
            let face = ready.withUnsafeSampleBuffer { sample -> EyeSample.Face? in
                guard let pixels = sample.imageBuffer else { return nil }
                return autoreleasepool { tracker.face(in: pixels) }
            }
            found.append(EyeSample(time: time, face: face))
            if time >= nextCheckpoint {
                let done = TimeSpan(start: from, end: min(span.end, time + frameLength))
                analysis.add(found, over: done)
                found = []
                from = done.end
                pass.checkpoint(analysis)
                nextCheckpoint = time + pass.interval
            }
        }
        analysis.add(found, over: TimeSpan(start: from, end: span.end))
        pass.checkpoint(analysis)
        return false
    }

    /// Follows the main face through one stretch's frames.
    private struct Tracker {
        let meshes: FaceMeshing
        let pass: Pass
        let crop = FaceCrop()
        let request = VNDetectFaceRectanglesRequest()
        /// Where the face mesh reads the next frame (from this frame's points); nil looks for the face.
        var region: FaceRegion?
        /// The main face's box at the last look for faces (top-left unit square), and whether someone else was beside it.
        var main: CGRect?
        var crowded = false
        var sinceDetection = Int.max

        init(meshes: FaceMeshing, pass: Pass) {
            self.meshes = meshes
            self.pass = pass
        }

        mutating func face(in frame: CVPixelBuffer) -> EyeSample.Face? {
            if region == nil || sinceDetection >= EyeContactAnalyzer.detectionEvery {
                detect(in: frame)
            }
            sinceDetection += 1
            guard let current = region, let cut = crop.cut(current, from: frame, uprightFromBuffer: pass.uprightFromBuffer),
                  let mesh = meshes.mesh(in: cut), mesh.score >= EyeContactAnalyzer.leastFaceScore,
                  mesh.points.count == FaceMesh.count else {
                region = nil
                return nil
            }
            let toUpright = current.cropToUpright
            let upright = mesh.points.map { EyeContactAnalyzer.apply(toUpright, $0) }
            region = FaceRegion.around(upright, first: upright[FaceMesh.firstEye[0]], second: upright[FaceMesh.secondEye[0]])
            guard var face = EyeContactAnalyzer.face(upright, size: pass.size, score: mesh.score) else { return nil }
            face.crowded = crowded
            face.sharpness = EyeContactAnalyzer.sharpness(of: cut, crop: mesh.points)
            return face
        }

        /// Looks for faces: the main one is found again (or first), and whether another is beside it.
        private mutating func detect(in frame: CVPixelBuffer) {
            sinceDetection = 0
            let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: pass.orientation, options: [:])
            guard (try? handler.perform([request])) != nil else { return }
            // Vision's boxes are on the bottom-left unit square.
            let boxes = (request.results ?? []).map { face in
                CGRect(x: face.boundingBox.minX, y: 1 - face.boundingBox.maxY, width: face.boundingBox.width, height: face.boundingBox.height)
            }
            let followed = region.map { region -> CGRect in
                let half = region.side / 2 / FaceRegion.landmarksScale
                return CGRect(
                    x: (region.center.x - half) / Double(pass.size.width), y: (region.center.y - half) / Double(pass.size.height),
                    width: 2 * half / Double(pass.size.width), height: 2 * half / Double(pass.size.height)
                )
            } ?? main
            guard let chosen = EyeContactAnalyzer.mainFace(in: boxes, following: followed) else {
                main = nil
                crowded = false
                return
            }
            main = chosen
            crowded = boxes.contains { EyeContactAnalyzer.overlap($0, chosen) < 0.3 && $0.width >= EyeContactAnalyzer.crowdedShare * chosen.width }
            if region == nil {
                let pixels = CGRect(
                    x: chosen.minX * pass.size.width, y: chosen.minY * pass.size.height,
                    width: chosen.width * pass.size.width, height: chosen.height * pass.size.height
                )
                region = FaceRegion.around(box: pixels, roll: 0)
            }
        }
    }

    // MARK: - Faces

    /// The main person's face among `boxes` (top-left unit square): the one overlapping `previous` when there is one, else the largest.
    static func mainFace(in boxes: [CGRect], following previous: CGRect?) -> CGRect? {
        let followed = previous.flatMap { previous in
            boxes.filter { overlap($0, previous) > 0.3 }.max { overlap($0, previous) < overlap($1, previous) }
        }
        return followed ?? boxes.max { $0.width < $1.width }
    }

    /// A face from its mesh in upright pixels: both eyes (image-left first) and their irises, its box, on the top-left unit square.
    static func face(_ points: [SIMD2<Double>], size: CGSize, score: Double) -> EyeSample.Face? {
        guard points.count == FaceMesh.count, size.width > 0, size.height > 0 else { return nil }
        let unit = SIMD2(Double(size.width), Double(size.height))
        let eyes = [(FaceMesh.firstEye, FaceMesh.firstIris), (FaceMesh.secondEye, FaceMesh.secondIris)].map { outline, iris in
            let edge = iris.dropFirst().map { points[$0] }
            let center = points[iris[0]]
            let radius = edge.map { (($0 - center) * ($0 - center)).sum().squareRoot() }.reduce(0, +) / Double(edge.count)
            return EyeShape(contour: outline.map { points[$0] / unit }, iris: center / unit, irisRadius: radius / Double(size.width))
        }.sorted { $0.frame.center.x < $1.frame.center.x }
        var low = points[0], high = points[0]
        for point in points {
            low = SIMD2(min(low.x, point.x), min(low.y, point.y))
            high = SIMD2(max(high.x, point.x), max(high.y, point.y))
        }
        let box = CGRect(x: low.x / unit.x, y: low.y / unit.y, width: (high.x - low.x) / unit.x, height: (high.y - low.y) / unit.y)
        return EyeSample.Face(box: box, confidence: score, crowded: false, eyes: eyes)
    }

    /// The eyes' sharpness in the crop (`FaceCrop.sharpness` over each eye's outline, averaged).
    static func sharpness(of crop: CVPixelBuffer, crop points: [SIMD2<Double>]) -> Double {
        let values = [FaceMesh.firstEye, FaceMesh.secondEye].map { outline -> Double in
            let eye = outline.map { points[$0] }
            let xs = eye.map(\.x), ys = eye.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return 0 }
            return FaceCrop.sharpness(of: crop, in: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        }
        return values.reduce(0, +) / Double(values.count)
    }

    static func apply(_ transform: CGAffineTransform, _ point: SIMD2<Double>) -> SIMD2<Double> {
        let mapped = CGPoint(x: point.x, y: point.y).applying(transform)
        return SIMD2(Double(mapped.x), Double(mapped.y))
    }

    /// Intersection over union of two boxes.
    static func overlap(_ a: CGRect, _ b: CGRect) -> Double {
        let shared = a.intersection(b)
        guard !shared.isNull else { return 0 }
        let common = shared.width * shared.height
        return Double(common / (a.width * a.height + b.width * b.height - common))
    }

    /// How a track's frames stand, for Vision, from its transform (the four turns, mirrored or not).
    static func orientation(of transform: CGAffineTransform) -> CGImagePropertyOrientation {
        let a = transform.a.rounded(), b = transform.b.rounded(), c = transform.c.rounded(), d = transform.d.rounded()
        switch (a, b, c, d) {
        case (0, 1, -1, 0): return .right
        case (-1, 0, 0, -1): return .down
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, 1): return .upMirrored
        case (1, 0, 0, -1): return .downMirrored
        case (0, 1, 1, 0): return .leftMirrored
        case (0, -1, -1, 0): return .rightMirrored
        default: return .up
        }
    }
}
