//
//  CueVideoCompositor.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders each frame of an edited take with Core Image: upright, cropped to the take's frame,
/// with Adjust and Filters, blended or darkened by a transition, then captions. Used by the Quick
/// edit preview and by exports, so both show exactly the same thing.
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
            // Inside a dissolve, the other side of the cut (see `EditedComposition`).
            let other = instruction.blendTrackID.flatMap { request.sourceReadOnlyPixelBuffer(byTrackID: $0) }
            source.withUnsafeBuffer { source in
                output.withUnsafeBuffer { output in
                    if let other {
                        other.withUnsafeBuffer { other in
                            let image = Self.composedImage(from: source, blending: other, instruction: instruction, at: time)
                            context.render(image.cropped(to: CGRect(origin: .zero, size: size)), to: output)
                        }
                    } else {
                        let image = Self.composedImage(from: source, blending: nil, instruction: instruction, at: time)
                        context.render(image.cropped(to: CGRect(origin: .zero, size: size)), to: output)
                    }
                }
            }
            request.finish(withComposedPixelBuffer: CVReadOnlyPixelBuffer(output))
        }
    }

    /// The source frame upright, cropped to the take's frame, with Adjust and Filters; blended with
    /// the other side of a dissolving cut and darkened inside a fade; then the captions visible at
    /// `time` and the output scale.
    nonisolated private static func composedImage(
        from source: CVPixelBuffer, blending other: CVPixelBuffer?, instruction: CompositionInstruction, at time: TimeInterval
    ) -> CIImage {
        var image = framed(source, instruction: instruction)
        if let other, let dissolve = instruction.dissolve {
            let otherSide = framed(other, instruction: instruction)
            // Before the cut the main track still shows the outgoing piece; after it, the incoming one.
            let (outgoing, incoming) = time < dissolve.cut ? (image, otherSide) : (otherSide, image)
            image = blend(outgoing, into: incoming, amount: dissolve.progress(at: time))
        }
        let blackness = instruction.fades.reduce(0) { max($0, $1.blackness(at: time)) }
        if blackness > 0 {
            image = blend(image, into: CIImage(color: .black).cropped(to: image.extent), amount: blackness)
        }
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

    /// A frame of the recording upright, cropped to the take's frame, with Adjust and Filters.
    nonisolated private static func framed(_ source: CVPixelBuffer, instruction: CompositionInstruction) -> CIImage {
        var image = CIImage(cvPixelBuffer: source).transformed(by: uprightTransform(instruction.transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(source))))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        image = image.cropped(to: instruction.crop)
            .transformed(by: CGAffineTransform(translationX: -instruction.crop.minX, y: -instruction.crop.minY))
        return FrameLook.apply(instruction.edit, to: image)
    }

    /// `from` turning into `to`: all `from` at 0, all `to` at 1.
    nonisolated private static func blend(_ from: CIImage, into to: CIImage, amount: Double) -> CIImage {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = from
        filter.targetImage = to
        filter.time = Float(min(max(0, amount), 1))
        return filter.outputImage?.cropped(to: from.extent) ?? from
    }

    /// The track transform is in UIKit coordinates (origin top left); Core Image's origin is at the
    /// bottom left, so the rotation is flipped around the frame.
    nonisolated static func uprightTransform(_ transform: CGAffineTransform, sourceHeight: CGFloat) -> CGAffineTransform {
        let flip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -sourceHeight)
        return flip.concatenating(transform).concatenating(CGAffineTransform(scaleX: 1, y: -1))
    }
}
