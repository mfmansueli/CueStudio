//
//  CueVideoCompositor.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import os

/// Renders each frame of an edited take with Core Image: upright, cropped to the
/// take's frame, with its background blurred or replaced (the person found by Vision, or a chroma key), with
/// Adjust and Filters, blended, slid or darkened by a transition, in its area of a split screen beside a support, with the
/// photo or video laid over it (B-roll), then texts and captions. Used by the Quick
/// edit preview and by exports, so both show exactly the same thing.
final class CueVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let context: CIContext
    /// Captions drawn as they show, the last few kept.
    private let overlayCache = OverlayImageCache()
    /// Where the person is, for background effects; the last masks kept.
    private let masker = PersonMasker()
    /// Where the faces are, for Skin Smoothing; only asked while a clip's dial is above 0.
    private let skin: SkinSmoother
    /// The frame composed last, which the preview holds on screen while it swaps to a new item.
    private let lastComposed = OSAllocatedUnfairLock<CVReadOnlyPixelBuffer?>(initialState: nil)
    /// One autorelease pool per frame: Core Image and Vision (Skin Smoothing, the person mask) leave autoreleased objects behind on every
    /// frame, and on a queue that never drained them an export of a minute grew until the system killed the app (on the iPhone, sharing
    /// a take with Skin Smoothing on).
    private let queue = DispatchQueue(label: "studio.cue.compositor", autoreleaseFrequency: .workItem)

    override init() {
        let context = CIContext(options: [.cacheIntermediates: false])
        self.context = context
        skin = SkinSmoother(context: context)
        super.init()
    }

    /// In IOSurfaces, which Core Image and Metal read in place.
    nonisolated let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: String](),
        kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    nonisolated let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ]

    nonisolated func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    nonisolated func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [context, overlayCache, masker, skin, lastComposed] in
            guard let instruction = request.videoCompositionInstruction as? CompositionInstruction else {
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
            let media = instruction.mediaTrackIDs.compactMap { id in request.sourceReadOnlyPixelBuffer(byTrackID: id).map { (id, $0) } }
            let bounds = CGRect(origin: .zero, size: size)
            // A piece whose recording is gone plays black for its length rather than failing.
            guard let source = request.sourceReadOnlyPixelBuffer(byTrackID: instruction.trackID) else {
                output.withUnsafeBuffer { output in
                    // Black at the take's frame size, so texts and captions keep their places.
                    let scale = max(0.000_1, instruction.outputScale)
                    let frame = CGRect(x: 0, y: 0, width: size.width / scale, height: size.height / scale)
                    let black = CIImage(color: .black).cropped(to: frame)
                    context.render(Self.decorated(black, instruction: instruction, at: time, cache: overlayCache).cropped(to: bounds), to: output)
                }
                let composed = CVReadOnlyPixelBuffer(output)
                lastComposed.withLock { $0 = composed }
                request.finish(withComposedPixelBuffer: composed)
                return
            }
            // The pixels are only valid inside each `withUnsafeBuffer`, so the frame is composed and
            // rendered in the innermost one.
            source.withUnsafeBuffer { source in
                output.withUnsafeBuffer { output in
                    Self.withBuffers(media) { media in
                        if let other {
                            other.withUnsafeBuffer { other in
                                let image = Self.composedImage(
                                    from: source, blending: other, media: media, instruction: instruction, at: time,
                                    cache: overlayCache, faces: (masker, skin)
                                )
                                context.render(image.cropped(to: bounds), to: output)
                            }
                        } else {
                            let image = Self.composedImage(
                                from: source, blending: nil, media: media, instruction: instruction, at: time,
                                cache: overlayCache, faces: (masker, skin)
                            )
                            context.render(image.cropped(to: bounds), to: output)
                        }
                    }
                }
            }
            let composed = CVReadOnlyPixelBuffer(output)
            lastComposed.withLock { $0 = composed }
            request.finish(withComposedPixelBuffer: composed)
        }
    }

    /// A copy of the frame composed last; nil before the first one. While paused it's the frame on
    /// screen, and while playing at most a few frames ahead of it.
    nonisolated func lastFrame() -> CGImage? {
        guard let frame = lastComposed.withLock({ $0 }) else { return nil }
        return frame.withUnsafeBuffer { buffer in
            let image = CIImage(cvPixelBuffer: buffer)
            return context.createCGImage(image, from: image.extent)
        }
    }

    /// Opens each buffer in turn (their pixels are only valid inside `withUnsafeBuffer`) and hands
    /// them all, by track, to `body`.
    nonisolated private static func withBuffers(
        _ buffers: [(CMPersistentTrackID, CVReadOnlyPixelBuffer)], opened: [CMPersistentTrackID: CVPixelBuffer] = [:],
        _ body: ([CMPersistentTrackID: CVPixelBuffer]) -> Void
    ) {
        guard let (id, first) = buffers.first else {
            body(opened)
            return
        }
        first.withUnsafeBuffer { buffer in
            var next = opened
            next[id] = buffer
            withBuffers(Array(buffers.dropFirst()), opened: next, body)
        }
    }

    /// The source frame upright, cropped to the take's frame, with Adjust and Filters; blended with
    /// (or slid over by) the other side of a transition's cut; with the photos and videos laid over
    /// it in their stacking order;
    /// darkened inside a fade; then the texts and captions visible at `time` and the output scale.
    nonisolated private static func composedImage(
        from source: CVPixelBuffer, blending other: CVPixelBuffer?, media: [CMPersistentTrackID: CVPixelBuffer],
        instruction: CompositionInstruction, at time: TimeInterval, cache: OverlayImageCache,
        faces: (masker: PersonMasker, skin: SkinSmoother)
    ) -> CIImage {
        let moment = Int((time * 1000).rounded())
        // The stretch of video this frame belongs to: the faces found in it carry from frame to frame, and are forgotten at its edges.
        let stretch = instruction.timeRange.start.seconds
        // A support showing: the main video goes to its own area, framed there; without one it has the whole frame.
        let support = instruction.media.first { $0.isSupport && $0.isVisible(at: time) }
        let mainArea = support?.areas?.main.size
        var image = framed(
            source,
            as: Framing(
                frame: instruction.frame, cropFit: instruction.edit.cropFit, look: instruction.look,
                key: mainArea == nil ? "main-\(moment)" : "main-split-\(moment)",
                moment: SmoothingMoment(stream: .main, stretch: stretch, time: time), sourceTime: instruction.sourceTime(at: time),
                lookTime: time - instruction.timeOrigin, area: mainArea.map { ($0, instruction.mainFraming) },
                blurs: instruction.blurs(at: time)
            ),
            faces: faces
        )
        if let zoom = instruction.zoom {
            image = FramePipeline.zoomed(image, by: CGFloat(zoom.scale(at: time)))
        }
        if let other, let dissolve = instruction.dissolve {
            let otherSide = framed(
                other,
                as: Framing(
                    frame: instruction.blendFrame ?? instruction.frame, cropFit: instruction.edit.cropFit,
                    look: instruction.blendLook ?? instruction.look, key: mainArea == nil ? "blend-\(moment)" : "blend-split-\(moment)",
                    moment: SmoothingMoment(stream: .blend, stretch: stretch, time: time), sourceTime: dissolve.otherSideSourceTime(at: time),
                    lookTime: time - instruction.timeOrigin,
                    area: mainArea.map { ($0, instruction.blendMainFraming ?? instruction.mainFraming) },
                    blurs: instruction.blendBlurs(atSource: dissolve.otherSideSourceTime(at: time))
                ),
                faces: faces
            )
            // Before the cut the main track still shows the outgoing piece; after it, the incoming one.
            let (outgoing, incoming) = time < dissolve.cut ? (image, otherSide) : (otherSide, image)
            switch dissolve.transition {
            case .slide: image = slide(incoming, over: outgoing, amount: dissolve.slideProgress(at: time))
            case .dissolve, .hardCut, .fade: image = blend(outgoing, into: incoming, amount: dissolve.progress(at: time))
            default: image = TransitionDrawing.draw(dissolve.transition, from: outgoing, to: incoming, progress: dissolve.progress(at: time))
            }
        }
        if let support, let areas = support.areas {
            image = splitScreen(main: image, support: support, frame: support.trackID.flatMap { media[$0] }, areas: areas, at: time)
        }
        // Every other photo and video showing, lowest layer first; the same layer in the order they come in the edit, as the
        // editor stacks them (`QuickEditViewModel.visibleMediaStack`).
        let showing = instruction.media.enumerated().filter { !$0.element.isSupport && $0.element.isVisible(at: time) }
        for shown in showing.sorted(by: { ($0.element.layer, $0.offset) < ($1.element.layer, $1.offset) }).map(\.element) {
            image = laid(shown, frame: shown.trackID.flatMap { media[$0] }, over: image, at: time)
        }
        return decorated(image, instruction: instruction, at: time, cache: cache)
    }

    /// Fades, texts and captions over `image`, then the output scale.
    nonisolated private static func decorated(
        _ base: CIImage, instruction: CompositionInstruction, at time: TimeInterval, cache: OverlayImageCache
    ) -> CIImage {
        var image = base
        let blackness = instruction.fades.reduce(0) { max($0, $1.blackness(at: time)) }
        if blackness > 0 {
            image = blend(image, into: CIImage(color: .black).cropped(to: image.extent), amount: blackness)
        }
        for overlay in instruction.overlays where overlay.isVisible(at: time) {
            guard let placed = overlay.placed(at: time, cache: cache) else { continue }
            image = placed.composited(over: image)
        }
        if instruction.outputScale != 1 {
            image = image.transformed(by: CGAffineTransform(scaleX: instruction.outputScale, y: instruction.outputScale))
        }
        return image
    }

    /// A frame of a recording upright, steadied, cropped and scaled to the take's frame, with its background effect, Adjust
    /// and Filters, as `framing` says (`FramePipeline`, which frames the cover too).
    nonisolated private static func framed(
        _ source: CVPixelBuffer, as framing: Framing, faces: (masker: PersonMasker, skin: SkinSmoother)
    ) -> CIImage {
        FramePipeline.framed(FramePipeline.upright(source, transform: framing.frame.transform), as: framing, skin: faces.skin) { image, key in
            faces.masker.mask(for: image, key: key)
        }
    }

    /// A photo or video over the take: its Blur areas hidden, filling its place (cropped, centered, or as Mask › Picture framed
    /// it), its mask cut out (where its keyframes have the mask at `time`), on top of `image`, where its keyframes put it at
    /// `time`. A video without a frame at this moment leaves the take showing.
    nonisolated private static func laid(_ item: MediaFrame, frame: CVPixelBuffer?, over image: CIImage, at time: TimeInterval) -> CIImage {
        var picture: CIImage
        if let photo = item.image {
            picture = photo
        } else if let frame {
            picture = CIImage(cvPixelBuffer: frame)
                .transformed(by: FramePipeline.uprightTransform(item.transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(frame))))
        } else {
            return image
        }
        picture = picture.transformed(by: CGAffineTransform(translationX: -picture.extent.minX, y: -picture.extent.minY))
        picture = item.hidingBlurs(picture, at: time)
        // Always Fill over the place; Core Image's y grows upward, so the picture's top goes `origin.y` below the place's top.
        var framing = item.areaFraming
        framing.fit = .fill
        let placed = SplitPlacement.place(picture.extent.size, in: item.rect.size, framing: framing)
        picture = picture
            .transformed(by: CGAffineTransform(scaleX: placed.scale, y: placed.scale))
            .transformed(by: CGAffineTransform(
                translationX: item.rect.minX + placed.origin.x, y: item.rect.maxY - placed.origin.y - placed.size.height
            ))
            .cropped(to: item.rect)
        let state = item.motion?.state(at: time - item.span.start)
        if let mask = item.mask {
            picture = MaskDrawing.apply(mask, placement: state?.mask ?? mask.placement, to: picture, in: item.rect)
        }
        if item.opacity < 0.999, state == nil {
            picture = picture.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(item.opacity))])
        }
        if let state {
            // Keyframes: the laid picture moved to their center, scaled around its own, faded.
            let point = state.center.clamped
            let center = CGPoint(x: CGFloat(point.x) * item.frameSize.width, y: (1 - CGFloat(point.y)) * item.frameSize.height)
            let scale = CGFloat(state.scale)
            picture = picture.transformed(by: CGAffineTransform(translationX: -item.rect.midX, y: -item.rect.midY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
            let opacity = state.opacity * item.opacity
            if opacity < 0.999 {
                picture = picture.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))])
            }
        }
        return picture.composited(over: image)
    }

    /// A split screen: the main video (already drawn at its area's size) in its area, the support in the other as its framing
    /// says, on black where a picture doesn't reach (Fit), and the seam as the layout draws it (`SplitSeamDrawing`). A video
    /// without a frame at this moment leaves its area black rather than moving the main video.
    nonisolated private static func splitScreen(
        main: CIImage, support: MediaFrame, frame: CVPixelBuffer?, areas: SplitPlacement.Areas, at time: TimeInterval
    ) -> CIImage {
        let size = support.frameSize
        // Core Image measures y from the bottom.
        func flipped(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height) }
        var canvas = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        let mainRect = flipped(areas.main)
        canvas = main
            .transformed(by: CGAffineTransform(translationX: mainRect.minX - main.extent.minX, y: mainRect.minY - main.extent.minY))
            .cropped(to: mainRect)
            .composited(over: canvas)
        var picture: CIImage?
        if let photo = support.image {
            picture = photo
        } else if let frame {
            picture = CIImage(cvPixelBuffer: frame)
                .transformed(by: FramePipeline.uprightTransform(support.transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(frame))))
        }
        if let picture {
            let upright = support.hidingBlurs(
                picture.transformed(by: CGAffineTransform(translationX: -picture.extent.minX, y: -picture.extent.minY)), at: time
            )
            let rect = flipped(areas.support)
            canvas = FramePipeline.inArea(upright, size: rect.size, framing: support.areaFraming)
                .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
                .composited(over: canvas)
        }
        return SplitSeamDrawing.draw(areas.seam, on: canvas, areas: areas, height: size.height)
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
}
