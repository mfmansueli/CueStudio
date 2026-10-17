//
//  FakeCoverPictures.swift
//  Cue StudioTests
//

import UIKit
@testable import Cue_Studio

/// Cover Studio's pictures without video: a gray picture for any source (nil for `missing`), a person found or not, and the
/// cover drawn by the real renderer (it's quick and has no IO).
@MainActor
final class FakeCoverPictures: CoverPicturing {
    var missing: Set<CoverSource> = []
    var findsPerson = true
    private(set) var pictureRequests: [CoverSource] = []
    private(set) var renders = 0

    func picture(for source: CoverSource, videoURL: URL, edit: TakeEdit) async -> UIImage? {
        pictureRequests.append(source)
        guard !missing.contains(source) else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: 90, height: 160)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 90, height: 160))
        }
    }

    func cutout(of pictures: CoverCompositionRenderer.Pictures, composition: CoverComposition, size: CGSize) async -> CoverDesignRenderer.Cutout? {
        findsPerson ? CoverDesignRenderer.Cutout(person: pictures.main, outline: nil) : nil
    }

    func render(
        title: String, composition: CoverComposition, pictures: CoverCompositionRenderer.Pictures, size: CGSize,
        cutout: CoverDesignRenderer.Cutout?
    ) async -> UIImage {
        renders += 1
        return CoverCompositionRenderer.image(title: title, composition: composition, pictures: pictures, size: CGSize(width: 36, height: 64), cutout: cutout)
    }
}
