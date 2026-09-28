//
//  CueVideoCompositor.swift
//  Cue Studio
//

import AVFoundation
import CoreImage

/// Renders each frame of an edited take with Core Image: upright, cropped to the take's frame,
/// with Adjust and Filters, then captions. Used by the Quick edit preview and by
/// exports, so both show exactly the same thing.
final class CueVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let queue = DispatchQueue(label: "studio.cue.compositor")

    nonisolated let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ]
    nonisolated let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ]

    nonisolated func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    nonisolated func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [context] in
            guard let instruction = request.videoCompositionInstruction as? CompositionInstruction,
                  let source = request.sourceReadOnlyPixelBuffer(byTrackID: instruction.trackID)
            else {
                request.finish(with: NSError(domain: "studio.cue.compositor", code: 1))
                return
            }
            let output: CVMutablePixelBuffer
            do {
                output = try request.renderContext.makeMutablePixelBuffer()
            } catch {
                request.finish(with: error)
                return
            }
            let time = request.compositionTime.seconds
            let size = request.renderContext.size
            source.withUnsafeBuffer { source in
                output.withUnsafeBuffer { output in
                    let image = Self.composedImage(from: source, instruction: instruction, at: time)
                    context.render(image.cropped(to: CGRect(origin: .zero, size: size)), to: output)
                }
            }
            request.finish(withComposedPixelBuffer: CVReadOnlyPixelBuffer(output))
        }
    }

    /// The source frame upright, cropped to the take's frame, with Adjust and Filters, the
    /// captions visible at `time` and the output scale.
    nonisolated private static func composedImage(from source: CVPixelBuffer, instruction: CompositionInstruction, at time: TimeInterval) -> CIImage {
        var image = CIImage(cvPixelBuffer: source).transformed(by: uprightTransform(instruction.transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(source))))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        image = image.cropped(to: instruction.crop)
            .transformed(by: CGAffineTransform(translationX: -instruction.crop.minX, y: -instruction.crop.minY))
        image = FrameLook.apply(instruction.edit, to: image)
        for overlay in instruction.overlays where overlay.isVisible(at: time) {
            image = overlay.image
                .transformed(by: CGAffineTransform(translationX: overlay.origin.x, y: overlay.origin.y))
                .composited(over: image)
        }
        if instruction.outputScale != 1 {
            image = image.transformed(by: CGAffineTransform(scaleX: instruction.outputScale, y: instruction.outputScale))
        }
        return image
    }

    /// The track transform is in UIKit coordinates (origin top left); Core Image's origin is at the
    /// bottom left, so the rotation is flipped around the frame.
    nonisolated static func uprightTransform(_ transform: CGAffineTransform, sourceHeight: CGFloat) -> CGAffineTransform {
        let flip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -sourceHeight)
        return flip.concatenating(transform).concatenating(CGAffineTransform(scaleX: 1, y: -1))
    }
}
