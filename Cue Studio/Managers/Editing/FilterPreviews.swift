//
//  FilterPreviews.swift
//  Cue Studio
//

import CoreImage
import UIKit

/// A frame of the take through each filter, for the Filters tool.
nonisolated enum FilterPreviews {
    static func render(_ image: UIImage) -> [VideoFilter: UIImage] {
        guard let source = CIImage(image: image) else { return [:] }
        let context = CIContext()
        var result: [VideoFilter: UIImage] = [:]
        for filter in VideoFilter.allCases {
            var edit = TakeEdit(sourceDuration: 1, aspect: .portrait)
            edit.filter = filter
            let output = FrameLook.apply(edit, to: source)
            if let cgImage = context.createCGImage(output, from: source.extent) {
                result[filter] = UIImage(cgImage: cgImage)
            }
        }
        return result
    }
}
