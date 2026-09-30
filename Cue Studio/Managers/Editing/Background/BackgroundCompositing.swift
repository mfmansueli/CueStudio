//
//  BackgroundCompositing.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// A recording's frame with its background blurred or replaced: behind the person (a mask from
/// `PersonMasker`) or in place of the key color. Shared by the compositor and the cover, so both
/// show the same.
nonisolated enum BackgroundCompositing {
    /// `image` (the frame, cropped, origin at zero) with its background changed. `mask` is asked
    /// only for a person cutout; without one (Vision couldn't tell) the frame stays as it is.
    static func apply(_ image: CIImage, render: BackgroundRender, mask: (CIImage) -> CIImage?) -> CIImage {
        let extent = image.extent
        guard let background = background(for: image, render: render) else { return image }
        switch render.effect.cutout {
        case .person:
            guard let mask = mask(image) else { return image }
            let blend = CIFilter.blendWithMask()
            blend.inputImage = image
            blend.backgroundImage = background
            blend.maskImage = mask
            return blend.outputImage?.cropped(to: extent) ?? image
        case .colorKey:
            guard let cube = render.cube else { return image }
            let key = CIFilter.colorCubeWithColorSpace()
            key.inputImage = image
            key.cubeDimension = Float(ChromaKeyCube.size)
            key.cubeData = cube
            key.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            guard let keyed = key.outputImage else { return image }
            return keyed.composited(over: background).cropped(to: extent)
        }
    }

    /// What goes behind: the frame blurred, a color, or the photo filling the frame.
    static func background(for image: CIImage, render: BackgroundRender) -> CIImage? {
        let extent = image.extent
        switch render.effect.style {
        case .original:
            return nil
        case .blur:
            let sigma = render.effect.blur * 0.04 * min(extent.width, extent.height)
            return image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        case .color:
            let color = render.effect.color.components
            return CIImage(color: CIColor(red: color.red, green: color.green, blue: color.blue)).cropped(to: extent)
        case .image:
            guard let photo = render.image else { return nil }
            let size = photo.extent.size
            guard size.width > 0, size.height > 0 else { return nil }
            let scale = max(extent.width / size.width, extent.height / size.height)
            let scaled = photo
                .transformed(by: CGAffineTransform(translationX: -photo.extent.minX, y: -photo.extent.minY))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let offsetX = extent.minX + (extent.width - size.width * scale) / 2
            let offsetY = extent.minY + (extent.height - size.height * scale) / 2
            return scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY)).cropped(to: extent)
        }
    }
}
