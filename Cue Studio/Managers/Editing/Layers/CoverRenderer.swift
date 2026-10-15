//
//  CoverRenderer.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import UIKit

/// Draws a take's cover: a frame of one of the edit's recordings (cropped to the take's frame, with the look of the clip it was
/// picked on) or a photo filling that frame, then the title set like the edit's texts. All on the device.
nonisolated enum CoverRenderer {
    /// Width of the cover image in pixels.
    static let width: CGFloat = 1080

    static func image(for cover: VideoCover, videoURL: URL, edit: TakeEdit, width: CGFloat = CoverRenderer.width) async -> UIImage? {
        let aspect = CGFloat(edit.aspect.widthOverHeight)
        let size = CGSize(width: width.rounded(), height: (width / aspect).rounded())
        let picture: UIImage?
        switch cover.source {
        case .frame, .clipFrame:
            guard let frame = cover.source.frame, let url = recordingURL(of: frame, videoURL: videoURL, edit: edit) else { return nil }
            picture = await self.frame(of: url, frame: frame, edit: edit).map { UIImage(cgImage: $0) }
        case .photo(let fileName):
            // Drawing a UIImage honors its orientation.
            picture = UIImage(contentsOfFile: EditMediaFiles.url(for: fileName).path(percentEncoded: false))
        }
        guard let picture else { return nil }
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

    /// The file of the recording `frame` is from: the take's, or another recording of the montage's (nil when the edit no
    /// longer knows it).
    static func recordingURL(of frame: CoverFrame, videoURL: URL, edit: TakeEdit) -> URL? {
        guard let id = frame.sourceID else { return videoURL }
        return edit.sources.first { $0.id == id }.map { EditMediaFiles.url(for: $0.fileName) }
    }

    /// `frame` of the recording at `url`, upright, cropped like the edit and with the look of the clip showing it.
    private static func frame(of url: URL, frame picked: CoverFrame, edit: TakeEdit) async -> CGImage? {
        let time = picked.time
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let result = try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)) else { return nil }
        let full = result.image
        let crop = CropMath.crop(
            in: CGSize(width: full.width, height: full.height),
            aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset
        )
        guard let cropped = full.cropping(to: crop) else { return full }
        var image = CIImage(cgImage: cropped)
        if edit.cropFit == .fit {
            // Fit: the whole frame on black, like the video.
            image = CueVideoCompositor.fitted(CIImage(cgImage: full), into: crop.size)
        }
        // The background and look of the clip showing it, like the video; the recording's own once no clip does.
        let clip = edit.clip(showing: picked)?.segment
        let effect = clip.map { edit.background(for: $0) } ?? edit.background(for: picked.sourceID)
        let look = clip.map { edit.lookSettings(for: $0) } ?? LookSettings(edit)
        let context = CIContext(options: [.cacheIntermediates: false])
        // Skin Smoothing like the video's: the faces of this frame, found on the frame as recorded (before a background goes behind the creator).
        let skin = SkinSmoother(context: context).pass(for: image, value: look.skinSmoothing, stream: .main, epoch: 0, time: time)
        if let effect, let render = BackgroundRender.prepare(effect, cacheKey: "cover") {
            image = BackgroundCompositing.apply(image, render: render) { PersonMasker.mask(for: $0) }
        }
        let looked = FrameLook.apply(look, to: image, skin: skin)
        return context.createCGImage(looked, from: looked.extent) ?? cropped
    }
}
