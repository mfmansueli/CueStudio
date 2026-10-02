//
//  FilterPreviews.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// A frame of the video through each filter, for the Filters tool: the picture the creator is
/// editing, drawn by the same `FrameLook` as the preview and the export, at the intensity each
/// filter starts with. The sets are kept for a while (`key`), so reopening the tool or picking
/// another filter doesn't draw them again.
nonisolated enum FilterPreviews {
    /// The thumbnails of one frame; `NSCache` holds classes.
    final class Thumbnails: @unchecked Sendable {
        let images: [VideoFilter: UIImage]
        init(_ images: [VideoFilter: UIImage]) { self.images = images }
    }

    nonisolated(unsafe) private static let sets: NSCache<NSString, Thumbnails> = {
        let cache = NSCache<NSString, Thumbnails>()
        cache.countLimit = 6
        return cache
    }()

    /// The kept set for `key` (a video and the moment of the frame), if there is one.
    static func kept(for key: String) -> [VideoFilter: UIImage]? {
        sets.object(forKey: key as NSString)?.images
    }

    /// Every filter on `image`, kept under `key` when given.
    static func render(_ image: UIImage, key: String? = nil) -> [VideoFilter: UIImage] {
        guard let source = CIImage(image: image) else { return [:] }
        let context = CIContext()
        var result: [VideoFilter: UIImage] = [:]
        for filter in VideoFilter.allCases {
            var edit = TakeEdit(sourceDuration: 1, aspect: .portrait)
            edit.filter = filter
            edit.filterAmount = filter.defaultAmount
            let output = FrameLook.apply(edit, to: source)
            if let cgImage = context.createCGImage(output, from: source.extent) {
                result[filter] = UIImage(cgImage: cgImage)
            }
        }
        if let key { sets.setObject(Thumbnails(result), forKey: key as NSString) }
        return result
    }
}
