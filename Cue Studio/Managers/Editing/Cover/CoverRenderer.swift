//
//  CoverRenderer.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import UIKit

/// Draws a take's cover: a frame of one of the edit's recordings (framed exactly as the video shows it there, `FramePipeline`)
/// or a photo filling that frame, then the Cover Studio composition (`CoverCompositionRenderer`), the v26 design or
/// the plain title of covers made before them. All on the device.
nonisolated enum CoverRenderer {
    /// Width of the cover image in pixels.
    static let width: CGFloat = 1080

    @concurrent
    static func image(for cover: VideoCover, videoURL: URL, edit: TakeEdit, width: CGFloat = CoverRenderer.width) async -> UIImage? {
        let aspect = CGFloat(edit.aspect.widthOverHeight)
        let size = CGSize(width: width.rounded(), height: (width / aspect).rounded())
        guard let picture = await picture(for: cover.source, videoURL: videoURL, edit: edit) else { return nil }
        if let composition = cover.composition {
            var pictures = CoverCompositionRenderer.Pictures(main: picture)
            if let second = composition.activeSplit?.source { pictures.second = await self.picture(for: second, videoURL: videoURL, edit: edit) }
            let cutout = composition.effect.needsPersonMask
                ? CoverDesignRenderer.cutout(
                    of: CoverCompositionRenderer.picturesLayer(composition, pictures: pictures, size: size), outlined: composition.effect == .outline
                )
                : nil
            return CoverCompositionRenderer.image(title: cover.title, composition: composition, pictures: pictures, size: size, cutout: cutout)
        }
        if let design = cover.design { return designImage(cover: cover, design: design, picture: picture, size: size) }
        let title = cover.titleOverlay.flatMap { TextOverlayRenderer.image(for: $0, frameWidth: size.width) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let content = picture.size
            let fill = MediaPlacement.fill(content, into: size)
            picture.draw(in: CGRect(
                x: fill.offset.x, y: fill.offset.y,
                width: content.width * fill.scale, height: content.height * fill.scale
            ))
            if let title, let overlay = cover.titleOverlay {
                let center = overlay.center
                title.draw(at: CGPoint(
                    x: (CGFloat(center.x) * size.width - title.size.width / 2).rounded(),
                    y: (CGFloat(center.y) * size.height - title.size.height / 2).rounded()
                ))
            }
        }
    }

    /// A v26 cover: the picture filling the frame (blurred for "Blur back"), then the design on top
    /// (and, for the effects that lift the person, the person cut out over the words).
    private static func designImage(cover: VideoCover, design: CoverDesign, picture: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        func filled(_ image: UIImage) -> UIImage {
            UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                let fill = MediaPlacement.fill(image.size, into: size)
                image.draw(in: CGRect(
                    x: fill.offset.x, y: fill.offset.y, width: image.size.width * fill.scale, height: image.size.height * fill.scale
                ))
            }
        }
        let base = filled(picture)
        let cutout = design.effect.needsPersonMask ? CoverDesignRenderer.cutout(of: base, outlined: design.effect == .outline) : nil
        let background = design.effect == .blur ? CoverDesignRenderer.blurred(base, width: size.width) : base
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            background.draw(in: CGRect(origin: .zero, size: size))
            CoverDesignRenderer.draw(cover: cover, design: design, size: size, cutout: cutout, in: context.cgContext)
        }
    }

    /// The picture `source` shows: a frame of one of the edit's recordings (as the video shows it), or a photo, upright. Nil
    /// when it can't be read.
    /// Off the main actor: Vision (skin, the person) and the full frame's look are heavy.
    @concurrent
    static func picture(for source: CoverSource, videoURL: URL, edit: TakeEdit) async -> UIImage? {
        switch source {
        case .frame, .clipFrame:
            guard let frame = source.frame, let url = recordingURL(of: frame, videoURL: videoURL, edit: edit) else { return nil }
            return await self.frame(of: url, frame: frame, edit: edit, videoURL: videoURL).map { UIImage(cgImage: $0) }
        case .photo(let fileName):
            // Drawing a UIImage honors its orientation.
            return UIImage(contentsOfFile: EditMediaFiles.url(for: fileName).path(percentEncoded: false))
        }
    }

    /// The file of the recording `frame` is from: the take's, or another recording of the montage's (nil when the edit no
    /// longer knows it).
    static func recordingURL(of frame: CoverFrame, videoURL: URL, edit: TakeEdit) -> URL? {
        guard let id = frame.sourceID else { return videoURL }
        return edit.sources.first { $0.id == id }.map { EditMediaFiles.url(for: $0.fileName) }
    }

    /// `frame` of the recording at `url` as the video shows it (`FramePipeline`, `EditFraming`): steadied, cropped where Follow
    /// face has it (or fitted), brought to the take's frame, with the background, Skin Smoothing and look of the clip showing
    /// it and that clip's zoom at that moment. A frame no clip shows any more is drawn with its recording's own background
    /// and the take's look. Transitions, B-roll, texts and captions stay off the cover: it has a title of its own.
    private static func frame(of url: URL, frame picked: CoverFrame, edit: TakeEdit, videoURL: URL) async -> CGImage? {
        let time = picked.time
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let result = try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)) else { return nil }
        let full = result.image
        // Upright already: the generator applies the track's transform.
        let shape = EditFraming.Shape(transform: .identity, uprightSize: CGSize(width: full.width, height: full.height))
        // The take's frame decides the crop and the scale another recording of a montage is brought to.
        let takeShape = picked.sourceID == nil ? shape : (await EditFraming.shape(of: videoURL) ?? shape)
        let analyses = (try? await EditedComposition.motionAnalyses(take: videoURL, edit: edit, analyzesMissing: false)) ?? [:]
        var framing = EditFraming(
            edit: edit, take: videoURL, takeShape: takeShape, shapes: picked.sourceID.map { [$0: shape] } ?? [:], analyses: analyses,
            cacheKey: "cover"
        )
        let shown = edit.clip(showing: picked)
        let editedTime = edit.editedTime(of: picked) ?? 0
        let context = CIContext(options: [.cacheIntermediates: false])
        var image = FramePipeline.framed(
            CIImage(cgImage: full),
            as: Framing(
                frame: shown.map { framing.frame(of: $0.segment) } ?? framing.frame(forRecording: picked.sourceID), cropFit: edit.cropFit,
                look: shown.map { edit.lookSettings(for: $0.segment) } ?? LookSettings(edit), key: "cover",
                moment: SmoothingMoment(stream: .main, stretch: 0, time: editedTime), sourceTime: time
            ),
            skin: SkinSmoother(context: context)
        ) { image, _ in
            PersonMasker.mask(for: image)
        }
        if let (index, segment) = shown, let zoom = segment.zoom {
            let window = ZoomWindow(
                zoom: zoom, start: edit.timeline.editedStart(ofSegmentAt: index), duration: segment.duration, amount: segment.zoomAmount
            )
            image = FramePipeline.zoomed(image, by: CGFloat(window.scale(at: editedTime)))
        }
        return context.createCGImage(image, from: image.extent) ?? full
    }
}
