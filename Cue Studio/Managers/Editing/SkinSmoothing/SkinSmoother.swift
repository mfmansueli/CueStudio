//
//  SkinSmoother.swift
//  Cue Studio
//

import CoreImage
import CoreVideo
import Foundation

/// Finds the faces of the frames the compositor draws and prepares them for `SkinSmoothingFilter`, once for each piece of the video that is played in
/// order. It is what makes the smoothing steady:
/// - faces are looked for at most 20 times a second of the video (`detectionInterval`), and a frame in between uses the faces of the last look;
/// - a face found again is the same face (`SkinFaceTracker`): it moves smoothly, fades in when it enters the shot and out when it stops being found;
/// - a cut, a seek or a long gap forgets everything, so a frame never wears the faces of another one.
/// Asking again for the same moment costs nothing, so a paused frame is drawn from what was found. The picture is looked at only when something is asked
/// (the dial is above 0); at 0 nothing in here runs. Used on the compositor's queue (or by the cover, with one of its own); the lock only keeps the state
/// whole if two frames are ever asked at once.
nonisolated final class SkinSmoother: @unchecked Sendable {
    /// The two sides of a dissolve are two streams of video, each with its own faces.
    enum Stream: Int, CaseIterable {
        case main, blend
    }

    private struct Prepared {
        var id: Int
        /// Where the face's landmarks were when this was made (the frame's unit square): a later frame carries the face along by how far it has moved since.
        var center: CGPoint
        var region: CGRect
        var mask: CIImage
        var tone: SkinTone
        var width: Double
    }

    private struct State {
        var tracker = SkinFaceTracker()
        var epoch: Double?
        var detectedAt: TimeInterval?
        var prepared: [Prepared] = []
    }

    private let context: CIContext
    private let detector: FaceDetecting
    private let lock = NSLock()
    private var states: [Stream: State] = [:]
    /// The reduced copy of the frame that Vision and the skin tone are read from, kept from look to look (under the lock) while its size holds.
    private var reducedBuffer: CVPixelBuffer?
    /// The patch of skin the noise is measured on, in pixels (at the frame's own resolution).
    private static let noisePatchSide = 32

    /// What finds the faces when nothing else is given: Vision's. A compositor is made by AVFoundation from its class, with no way to hand it a detector,
    /// so a test that needs faces of its own (a drawing is not a face to Vision) sets this one, and puts it back.
    /// `nonisolated(unsafe)`: read when a compositor is made and written only by serial tests, never while a render runs.
    nonisolated(unsafe) static var makeDetector: @Sendable () -> FaceDetecting = { VisionFaceDetector() }

    init(context: CIContext, detector: FaceDetecting = SkinSmoother.makeDetector()) {
        self.context = context
        self.detector = detector
    }

    /// `pass(for:stream:epoch:time:)` when the dial is above 0, and nothing, without looking at the picture, when it is 0: the bypass.
    func pass(for image: CIImage, value: Double, stream: Stream, epoch: Double, time: TimeInterval) -> SkinSmoothingPass? {
        guard SkinSmoothingCalibration.isOn(value) else { return nil }
        return pass(for: image, stream: stream, epoch: epoch, time: time)
    }

    /// The faces to smooth in `image` (the frame as recorded, upright and cropped, its origin at zero) at `time` seconds of the video. `epoch` names the
    /// stretch of video that is playing (the compositor's instruction): when it changes, what was known is forgotten.
    func pass(for image: CIImage, stream: Stream, epoch: Double, time: TimeInterval) -> SkinSmoothingPass {
        lock.lock()
        defer { lock.unlock() }
        var state = states[stream] ?? State()
        defer { states[stream] = state }
        if state.epoch != epoch || !state.tracker.isContinuous(at: time) {
            state = State()
            state.epoch = epoch
        }
        let due = state.detectedAt.map { time < $0 || time - $0 >= SkinSmoothingCalibration.detectionInterval } ?? true
        if due {
            // One reduced copy of the frame, drawn by the GPU, is what Vision looks at and what the skin tone is measured on: neither needs a 4K frame.
            let reduced = reducedCopy(of: image)
            state.tracker.update(with: detector.faces(in: reduced.image), at: time)
            state.detectedAt = time
            state.prepared = state.tracker.faces(at: time).compactMap { prepare($0, in: image, reduced: reduced) }
        }
        let tracked = Dictionary(uniqueKeysWithValues: state.tracker.faces(at: time).map { ($0.id, $0) })
        let size = image.extent.size
        return SkinSmoothingPass(faces: state.prepared.compactMap { face in
            guard let now = tracked[face.id] else { return nil }
            // A frame between two detections: the face's mask moves with the face, a little each frame.
            let dx = (now.landmarks.center.x - face.center.x) * size.width, dy = (now.landmarks.center.y - face.center.y) * size.height
            let moved = dx != 0 || dy != 0
            return SkinFace(
                region: moved ? face.region.offsetBy(dx: dx, dy: dy) : face.region,
                mask: moved ? face.mask.transformed(by: CGAffineTransform(translationX: dx, y: dy)) : face.mask,
                tone: face.tone, width: face.width, presence: now.presence
            )
        })
    }

    // MARK: - Preparing a face

    /// `image` reduced to no more than `detectionSide` pixels on its longer side and drawn into a pixel buffer (`scale` is the share it was reduced by), or
    /// `image` itself when it is small already or the buffer can't be made.
    private func reducedCopy(of image: CIImage) -> (image: CIImage, scale: CGFloat) {
        let extent = image.extent
        let scale = min(1, SkinSmoothingCalibration.detectionSide / max(extent.width, extent.height))
        let width = Int((extent.width * scale).rounded()), height = Int((extent.height * scale).rounded())
        guard scale < 1, width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return (image, 1) }
        if reducedBuffer.map({ CVPixelBufferGetWidth($0) != width || CVPixelBufferGetHeight($0) != height }) ?? true {
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(
                nil, width, height, kCVPixelFormatType_32BGRA,
                [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary, kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary, &buffer
            )
            reducedBuffer = buffer
        }
        guard let buffer = reducedBuffer else { return (image, 1) }
        let reduced = image.cropped(to: extent)
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(width) / extent.width, y: CGFloat(height) / extent.height))
        context.render(reduced, to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: space)
        return (CIImage(cvPixelBuffer: buffer), CGFloat(width) / extent.width)
    }

    /// A tracked face's mask and skin tone, measured on this frame (the tone on its reduced copy, the noise on a patch of the frame itself); nil when it
    /// can't be drawn or no skin was found where skin should be.
    private func prepare(_ face: TrackedFace, in image: CIImage, reduced: (image: CIImage, scale: CGFloat)) -> Prepared? {
        let extent = image.extent
        guard face.landmarks.box.width * extent.width >= SkinSmoothingCalibration.minimumFaceWidth,
              let mask = SkinMaskRaster.make(face.landmarks, frame: extent.size), mask.coreCount >= SkinToneAnalyzer.minimumSamples,
              let maskImage = mask.image()
        else { return nil }
        let scale = reduced.scale
        let region = CGRect(x: mask.region.minX * scale, y: mask.region.minY * scale, width: mask.region.width * scale, height: mask.region.height * scale)
        guard let pixels = bitmap(of: reduced.image, in: region, width: mask.width, height: mask.height) else { return nil }
        let patch = noisePatch(of: image, mask: mask)
        guard let tone = SkinToneAnalyzer.measure(rgba: pixels, core: mask.core, noise: patch) else { return nil }
        return Prepared(
            id: face.id, center: face.landmarks.center, region: mask.region, mask: maskImage, tone: tone, width: face.landmarks.box.width * extent.width
        )
    }

    /// The picture over `rect` of the frame as `width` × `height` pixels of sRGB-encoded RGBA, rows from the top.
    private func bitmap(of image: CIImage, in rect: CGRect, width: Int, height: Int) -> [UInt8]? {
        guard rect.width > 0, rect.height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let moved = image.cropped(to: rect)
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(width) / rect.width, y: CGFloat(height) / rect.height))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            context.render(
                moved, toBitmap: base, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: space
            )
        }
        return pixels
    }

    /// How noisy the skin is, measured on a small patch of the frame's own pixels (not the reduced copy, where the noise is averaged away) around the
    /// middle of what is surely skin.
    private func noisePatch(of image: CIImage, mask: SkinMask) -> Double {
        var sumX = 0.0, sumY = 0.0, count = 0.0
        // Every fourth row and column is enough to find the middle.
        for row in stride(from: 0, to: mask.height, by: 4) {
            for column in stride(from: 0, to: mask.width, by: 4) where mask.core[row * mask.width + column] >= 128 {
                sumX += Double(column)
                sumY += Double(row)
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        // The patch is centered on the mean of the core, in the frame's pixels (the mask's rows run down from the top).
        let center = CGPoint(
            x: mask.region.minX + CGFloat(sumX / count + 0.5) * mask.region.width / CGFloat(mask.width),
            y: mask.region.maxY - CGFloat(sumY / count + 0.5) * mask.region.height / CGFloat(mask.height)
        )
        let side = CGFloat(Self.noisePatchSide)
        let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side).integral.intersection(image.extent)
        guard rect.width >= 8, rect.height >= 8,
              let pixels = bitmap(of: image, in: rect, width: Int(rect.width), height: Int(rect.height))
        else { return 0 }
        let green = stride(from: 1, to: pixels.count, by: 4).map { pixels[$0] }
        return SkinToneAnalyzer.noise(green: green, width: Int(rect.width))
    }
}
