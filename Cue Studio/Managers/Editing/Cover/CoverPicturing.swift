//
//  CoverPicturing.swift
//  Cue Studio
//

import UIKit

/// The pictures Cover Studio works with: a cover's picture (a frame of one of the edit's recordings with its clip's look, or a
/// photo), the person cut out of what's on the cover, and the cover drawn. Behind a protocol so the studio is tested with a
/// fake.
protocol CoverPicturing: AnyObject {
    /// Nil when the picture can't be read.
    func picture(for source: CoverSource, videoURL: URL, edit: TakeEdit) async -> UIImage?
    /// The person in `pictures` laid out as `composition` frames them, at `size`; nil when no person is found.
    func cutout(of pictures: CoverCompositionRenderer.Pictures, composition: CoverComposition, size: CGSize) async -> CoverDesignRenderer.Cutout?
    /// The cover drawn at `size`.
    func render(
        title: String, composition: CoverComposition, pictures: CoverCompositionRenderer.Pictures, size: CGSize,
        cutout: CoverDesignRenderer.Cutout?
    ) async -> UIImage
}
