//
//  CoverPictureService.swift
//  Cue Studio
//

import UIKit

/// Cover Studio's pictures with AVFoundation, Core Image and Vision, off the main actor, on the device.
@MainActor
final class CoverPictureService: CoverPicturing {
    func picture(for source: CoverSource, videoURL: URL, edit: TakeEdit) async -> UIImage? {
        await CoverRenderer.picture(for: source, videoURL: videoURL, edit: edit)
    }

    func cutout(of pictures: CoverCompositionRenderer.Pictures, composition: CoverComposition, size: CGSize) async -> CoverDesignRenderer.Cutout? {
        let outlined = composition.effect == .outline
        return await Task.detached(priority: .userInitiated) {
            let layer = CoverCompositionRenderer.picturesLayer(composition, pictures: pictures, size: size)
            return CoverDesignRenderer.cutout(of: layer, outlined: outlined)
        }.value
    }

    func render(
        title: String, composition: CoverComposition, pictures: CoverCompositionRenderer.Pictures, size: CGSize,
        cutout: CoverDesignRenderer.Cutout?
    ) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            CoverCompositionRenderer.image(title: title, composition: composition, pictures: pictures, size: size, cutout: cutout)
        }.value
    }
}
