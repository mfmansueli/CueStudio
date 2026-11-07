//
//  ExportFrameSize.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The pixels an export comes out in: the format's crop of the recording's upright frame (Fill and Fit crop the same frame; Fit puts
/// the whole recording inside it), brought down to the quality's short side and never enlarged. The export (`EditedComposition`) and
/// what the app says about it (Done, Export options, Aspect ratio) read this one rule, so "606×1080" is what the file has.
nonisolated enum ExportFrameSize {
    /// The file's size for a recording of `uprightSize` cropped to `aspect`; `shortSide` scales a larger crop down (nil keeps it).
    static func size(uprightSize: CGSize, aspect: AspectRatio, shortSide: CGFloat?) -> CGSize {
        let crop = CropMath.centeredCrop(in: uprightSize, aspect: aspect.widthOverHeight).size
        return size(ofCrop: crop, shortSide: shortSide)
    }

    /// A crop at the requested quality, with even dimensions. Never upscaled.
    static func size(ofCrop crop: CGSize, shortSide: CGFloat?) -> CGSize {
        guard let shortSide, crop.width > 0, crop.height > 0 else {
            return CGSize(width: CropMath.even(crop.width), height: CropMath.even(crop.height))
        }
        let scale = min(1, shortSide / min(crop.width, crop.height))
        return CGSize(width: CropMath.even(crop.width * scale), height: CropMath.even(crop.height * scale))
    }

    /// `size` when its short side is under the one its quality names (`nominalShortSide`: 1080 for 1080p), for the places that say what
    /// the file will be; nil when the quality's name is true.
    static func reduced(_ size: CGSize, nominalShortSide: CGFloat) -> CGSize? {
        guard size.width > 0, size.height > 0, min(size.width, size.height) < nominalShortSide - 0.5 else { return nil }
        return size
    }

    /// The file's size for `aspect` when the format's crop leaves fewer pixels than the quality (`nominalShortSide`) and than the whole
    /// recording at that quality: a recording that is itself smaller than its quality's name isn't the crop's doing, and isn't said here.
    static func reducedByCrop(uprightSize: CGSize, aspect: AspectRatio, shortSide: CGFloat?, nominalShortSide: CGFloat) -> CGSize? {
        let whole = size(ofCrop: uprightSize, shortSide: shortSide)
        let cropped = size(uprightSize: uprightSize, aspect: aspect, shortSide: shortSide)
        return reduced(cropped, nominalShortSide: min(nominalShortSide, min(whole.width, whole.height)))
    }

    /// "606×1080": width by height, in pixels.
    static func label(_ size: CGSize) -> String {
        "\(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
    }

    /// "This format exports at 606×1080 · never enlarged": said where the format or the quality is picked.
    static func note(_ size: CGSize) -> String {
        String(localized: "This format exports at \(label(size)) · never enlarged")
    }
}
