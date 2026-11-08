//
//  BackgroundCompositing.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// A recording's frame with its background blurred or replaced: behind the person (a mask from
/// `PersonMasker`) or in place of the key color, the creator moved and resized where `BackgroundEffect.person` says. Shared by the
/// compositor, the cover and the camera's live preview, so all show the same.
nonisolated enum BackgroundCompositing {
    /// `image` (the frame, cropped, origin at zero) with its background changed: `backdrop` (a photo or video shown Behind you) when
    /// there is one, else the effect's. `mask` is asked only for a person cutout; without one (no outline to show) the frame stays as
    /// it is.
    static func apply(_ image: CIImage, render: BackgroundRender, backdrop: CIImage? = nil, mask: (CIImage) -> CIImage?) -> CIImage {
        let extent = image.extent
        let effect = render.effect
        let behind = backdrop.flatMap { filled($0, in: extent) }
        guard behind != nil || effect.isActive else { return image }
        let person: CIImage
        switch effect.cutout {
        case .person:
            guard let mask = mask(image) else { return image }
            person = cutOut(image, mask: mask)
        case .colorKey:
            guard let cube = render.cube else { return image }
            let key = CIFilter.colorCubeWithColorSpace()
            key.inputImage = image
            key.cubeDimension = Float(ChromaKeyCube.size)
            key.cubeData = cube
            key.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            guard let keyed = key.outputImage else { return image }
            person = keyed.cropped(to: extent)
        }
        guard let background = behind ?? self.background(for: image, render: render, person: person) else { return image }
        let placed = effect.movesPerson ? person.transformed(by: effect.placement.transform(for: extent)) : person
        return placed.composited(over: background).cropped(to: extent)
    }

    /// The person alone: the frame where the mask is white, clear around it.
    private static func cutOut(_ image: CIImage, mask: CIImage) -> CIImage {
        let blend = CIFilter.blendWithMask()
        blend.inputImage = image
        blend.backgroundImage = CIImage(color: .clear).cropped(to: image.extent)
        blend.maskImage = mask
        return blend.outputImage?.cropped(to: image.extent) ?? image
    }

    /// What goes behind: the frame blurred, a color, or the photo filling the frame. With the creator moved or resized, the blur is
    /// of the frame without them (`person`, cut out), so where they stood shows the room blurred, not a ghost of them.
    static func background(for image: CIImage, render: BackgroundRender, person: CIImage? = nil) -> CIImage? {
        let extent = image.extent
        switch render.effect.style {
        case .original:
            return nil
        case .blur:
            let sigma = render.effect.blur * 0.04 * min(extent.width, extent.height)
            if render.effect.movesPerson, let person {
                return blurredWithout(person, in: image, sigma: sigma)
            }
            return image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        case .color:
            let color = render.effect.color.components
            return CIImage(color: CIColor(red: color.red, green: color.green, blue: color.blue)).cropped(to: extent)
        case .image:
            return render.image.flatMap { filled($0, in: extent) }
        }
    }

    /// A picture filling `extent`, cropped around its middle.
    static func filled(_ photo: CIImage, in extent: CGRect) -> CIImage? {
        let size = photo.extent.size
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return nil }
        let scale = max(extent.width / size.width, extent.height / size.height)
        let scaled = photo
            .transformed(by: CGAffineTransform(translationX: -photo.extent.minX, y: -photo.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let offsetX = extent.minX + (extent.width - size.width * scale) / 2
        let offsetY = extent.minY + (extent.height - size.height * scale) / 2
        return scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY)).cropped(to: extent)
    }

    /// The frame blurred with the creator taken out: the room around them, blurred and spread into where they stood (the blur of the
    /// frame without them divided by the blur of where it has something, so the hole fills from its edges). Two spreads: a tenth of the
    /// frame near the hole's edges, half of it deep inside a wide hole (where the near one gathers too little room to divide by), and the
    /// plain blur where even that has nothing (the creator filling the frame); the plain blur where the room was.
    private static func blurredWithout(_ person: CIImage, in image: CIImage, sigma: CGFloat) -> CIImage {
        let extent = image.extent
        // Where the room shows (1 − the person's alpha), opaque gray.
        let room = person.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: -1), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: -1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: -1), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 1),
        ]).cropped(to: extent)
        // The room alone, its alpha the share of room: blurred premultiplied, un-premultiplying divides by the room gathered.
        let roomOnly = mixed(image, over: CIImage(color: .clear).cropped(to: extent), where: room)
        let plain = image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        let wide = spread(roomOnly, sigma: max(sigma, 0.5 * max(extent.width, extent.height)), in: extent)
        let near = spread(roomOnly, sigma: max(sigma, 0.1 * min(extent.width, extent.height)), in: extent)
        let deep = mixed(wide.filled, over: plain, where: wide.enough)
        let filledIn = mixed(near.filled, over: deep, where: near.enough)
        return mixed(plain, over: filledIn, where: room)
    }

    /// The room spread by `sigma` (divided by how much room each point gathered) and where that is enough to trust: a tenth of the
    /// weight or more counts fully.
    private static func spread(_ roomOnly: CIImage, sigma: CGFloat, in extent: CGRect) -> (filled: CIImage, enough: CIImage) {
        let spread = roomOnly.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        let filled = spread.unpremultiplyingAlpha().settingAlphaOne(in: extent).applyingFilter("CIColorClamp").cropped(to: extent)
        let enough = spread.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 10), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 10),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 10), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ]).applyingFilter("CIColorClamp").cropped(to: extent)
        return (filled, enough)
    }

    /// `top` where `mask` is white, `bottom` where it is black.
    private static func mixed(_ top: CIImage, over bottom: CIImage, where mask: CIImage) -> CIImage {
        let blend = CIFilter.blendWithMask()
        blend.inputImage = top
        blend.backgroundImage = bottom
        blend.maskImage = mask
        return blend.outputImage?.cropped(to: bottom.extent) ?? bottom
    }
}
