//
//  CueVideoCompositor.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders each frame of an edited take with Core Image: upright, cropped to the take's frame,
/// with Adjust and Filters, blended, slid or darkened by a transition, with the photo or video laid
/// over it (B-roll), then texts and captions. Used by the Quick
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
            // Inside a dissolve, the other side of the cut (see `EditedComposition`); while a video
            // is laid over the take, its frame.
            let other = instruction.blendTrackID.flatMap { request.sourceReadOnlyPixelBuffer(byTrackID: $0) }
            let media = instruction.mediaTrackID.flatMap { request.sourceReadOnlyPixelBuffer(byTrackID: $0) }
            let bounds = CGRect(origin: .zero, size: size)
            // The pixels are only valid inside each `withUnsafeBuffer`, so the frame is composed and
            // rendered in the innermost one.
            source.withUnsafeBuffer { source in
                output.withUnsafeBuffer { output in
                    switch (other, media) {
                    case let (other?, media?):
                        other.withUnsafeBuffer { other in
                            media.withUnsafeBuffer { media in
                                let image = Self.composedImage(from: source, blending: other, media: media, instruction: instruction, at: time)
                                context.render(image.cropped(to: bounds), to: output)
                            }
                        }
                    case let (other?, nil):
                        other.withUnsafeBuffer { other in
                            let image = Self.composedImage(from: source, blending: other, media: nil, instruction: instruction, at: time)
                            context.render(image.cropped(to: bounds), to: output)
                        }
                    case let (nil, media?):
                        media.withUnsafeBuffer { media in
                            let image = Self.composedImage(from: source, blending: nil, media: media, instruction: instruction, at: time)
                            context.render(image.cropped(to: bounds), to: output)
                        }
                    case (nil, nil):
                        let image = Self.composedImage(from: source, blending: nil, media: nil, instruction: instruction, at: time)
                        context.render(image.cropped(to: bounds), to: output)
                    }
                }
            }
            request.finish(withComposedPixelBuffer: CVReadOnlyPixelBuffer(output))
        }
    }

    /// The source frame upright, cropped to the take's frame, with Adjust and Filters; blended with
    /// (or slid over by) the other side of a transition's cut; with the photo or video laid over it;
    /// darkened inside a fade; then the texts and captions visible at `time` and the output scale.
    nonisolated private static func composedImage(
        from source: CVPixelBuffer, blending other: CVPixelBuffer?, media: CVPixelBuffer?,
        instruction: CompositionInstruction, at time: TimeInterval
    ) -> CIImage {
        var image = framed(source, instruction: instruction)
        if let other, let dissolve = instruction.dissolve {
            let otherSide = framed(other, instruction: instruction)
            // Before the cut the main track still shows the outgoing piece; after it, the incoming one.
            let (outgoing, incoming) = time < dissolve.cut ? (image, otherSide) : (otherSide, image)
            if dissolve.transition == .slide {
                image = slide(incoming, over: outgoing, amount: dissolve.slideProgress(at: time))
            } else {
                image = blend(outgoing, into: incoming, amount: dissolve.progress(at: time))
            }
        }
        if let shown = instruction.media.first(where: { $0.isVisible(at: time) }) {
            image = laid(shown, frame: media, over: image)
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

    /// A photo or video over the take: filling its place (cropped, centered), on top of `image`.
    /// A video without a frame at this moment leaves the take showing.
    nonisolated private static func laid(_ item: MediaFrame, frame: CVPixelBuffer?, over image: CIImage) -> CIImage {
        var picture: CIImage
        if let photo = item.image {
            picture = photo
        } else if let frame {
            picture = CIImage(cvPixelBuffer: frame)
                .transformed(by: uprightTransform(item.transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(frame))))
        } else {
            return image
        }
        picture = picture.transformed(by: CGAffineTransform(translationX: -picture.extent.minX, y: -picture.extent.minY))
        let fill = MediaPlacement.fill(picture.extent.size, into: item.rect.size)
        picture = picture
            .transformed(by: CGAffineTransform(scaleX: fill.scale, y: fill.scale))
            .transformed(by: CGAffineTransform(translationX: item.rect.minX + fill.offset.x, y: item.rect.minY + fill.offset.y))
            .cropped(to: item.rect)
        return picture.composited(over: image)
    }

    /// `incoming` sliding in from the right over `outgoing`: none of it at 0, all of it at 1.
    nonisolated private static func slide(_ incoming: CIImage, over outgoing: CIImage, amount: Double) -> CIImage {
        let width = outgoing.extent.width
        let shift = width * CGFloat(1 - min(max(0, amount), 1))
        return incoming
            .transformed(by: CGAffineTransform(translationX: shift, y: 0))
            .cropped(to: outgoing.extent)
            .composited(over: outgoing)
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
