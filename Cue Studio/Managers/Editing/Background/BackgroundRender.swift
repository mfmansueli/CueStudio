//
//  BackgroundRender.swift
//  Cue Studio
//

import CoreImage
import Foundation

/// A recording's background effect ready for the compositor: the photo read once, the key's color
/// cube built once, and a name that keeps its masks apart from other recordings' and builds'.
nonisolated struct BackgroundRender: @unchecked Sendable {
    let effect: BackgroundEffect
    /// The photo behind the creator, for `.image`.
    let image: CIImage?
    /// The chroma key as a color cube, for `.colorKey`.
    let cube: Data?
    let cacheKey: String

    /// Nil when the effect doesn't change the picture (or its photo is gone).
    static func prepare(_ effect: BackgroundEffect, cacheKey: String) -> BackgroundRender? {
        guard effect.isActive else { return nil }
        var image: CIImage?
        if effect.style == .image {
            guard let name = effect.imageFileName,
                  let photo = CIImage(contentsOf: EditMediaFiles.url(for: name), options: [.applyOrientationProperty: true])
            else { return nil }
            image = photo
        }
        let cube = effect.cutout == .colorKey ? ChromaKeyCube.data(for: effect.key) : nil
        return BackgroundRender(effect: effect, image: image, cube: cube, cacheKey: cacheKey)
    }

    /// Only the cutout and the creator's place, whatever the background is (an Original one too), for a photo or video shown Behind
    /// you, which brings the picture behind.
    static func cutout(_ effect: BackgroundEffect, cacheKey: String) -> BackgroundRender {
        let cube = effect.cutout == .colorKey ? ChromaKeyCube.data(for: effect.key) : nil
        return BackgroundRender(effect: effect, image: nil, cube: cube, cacheKey: cacheKey + "-behind")
    }
}
