//
//  EyeContactStill.swift
//  Cue Studio
//

import CoreImage
import CoreVideo
import Foundation

/// Eye Contact on one picture taken from a recording (a cover's frame): the same decisions and drawing as the video's at that
/// moment, so the cover shows the eyes the video shows there. A photo picked as the cover never goes through it.
nonisolated enum EyeContactStill {
    /// `image` (the recording's frame at `time`, upright) with its eyes moved as the edit's Eye Contact moves them; the image as it
    /// is when the edit doesn't correct the eyes, the moment isn't analyzed or isn't corrected.
    static func corrected(
        _ image: CGImage, recording: URL, at time: TimeInterval, settings: EyeContactSettings?, context: CIContext,
        renderer: EyeContactRenderer = EyeContactRenderer()
    ) -> CGImage {
        guard let settings, let plan = EyeContactAnalysisStore.plan(forRecording: recording),
              let frame = plan.frame(at: time, strength: settings.strength),
              let buffer = buffer(of: image, context: context) else { return image }
        let picture = CIImage(cvPixelBuffer: buffer)
        let corrected = renderer.corrected(picture, source: buffer, transform: .identity, frame: frame)
        return context.createCGImage(corrected, from: picture.extent) ?? image
    }

    /// The picture in a BGRA buffer the GPU can read in place.
    private static func buffer(of image: CGImage, context: CIContext) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](), kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        CVPixelBufferCreate(nil, image.width, image.height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        guard let buffer else { return nil }
        context.render(CIImage(cgImage: image), to: buffer)
        return buffer
    }
}
