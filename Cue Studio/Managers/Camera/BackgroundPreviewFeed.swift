//
//  BackgroundPreviewFeed.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import Vision

/// The camera's frames with the background effect, for the Selfie preview while recording: small
/// frames (the preview's size), about 15 a second, the person found with Vision's fast quality. It
/// only draws what the creator sees; the recording keeps the camera's own image, and the effect is
/// added to the take as a recipe.
nonisolated final class BackgroundPreviewFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// Shortest time between two drawn frames.
    static let interval: TimeInterval = 1.0 / 15

    private let lock = NSLock()
    private var render: BackgroundRender?
    private var handler: (@Sendable (CGImage) -> Void)?
    private var lastDrawn: TimeInterval = 0
    private let masker = PersonMasker(quality: .fast)
    private let context = CIContext(options: [.cacheIntermediates: false])

    /// What to draw, and who gets each frame (on the capture's video queue). Nil stops it.
    func configure(render: BackgroundRender?, handler: (@Sendable (CGImage) -> Void)?) {
        lock.withLock {
            self.render = render
            self.handler = handler
            lastDrawn = 0
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let current = lock.withLock { () -> (BackgroundRender, @Sendable (CGImage) -> Void)? in
            guard let render, let handler, time - lastDrawn >= Self.interval else { return nil }
            lastDrawn = time
            return (render, handler)
        }
        guard let (render, handler) = current, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: buffer)
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let composed = BackgroundCompositing.apply(image, render: render) { [masker] in masker.mask(for: $0) }
        guard let frame = context.createCGImage(composed, from: composed.extent) else { return }
        handler(frame)
    }
}
