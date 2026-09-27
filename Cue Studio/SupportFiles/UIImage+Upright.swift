//
//  UIImage+Upright.swift
//  Cue Studio
//

import UIKit

extension UIImage {
    /// The pixels turned the way the photo is meant to be seen. Camera photos keep their rotation
    /// in metadata, and text recognition reads raw pixels.
    var uprightCGImage: CGImage? {
        guard imageOrientation != .up else { return cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
