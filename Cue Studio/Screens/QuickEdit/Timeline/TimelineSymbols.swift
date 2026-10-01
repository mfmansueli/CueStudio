//
//  TimelineSymbols.swift
//  Cue Studio
//

import UIKit

/// SF Symbols drawn as images in a color, for the timeline's layers (which can't tint a template
/// image), kept once drawn.
@MainActor
enum TimelineSymbols {
    private static var cache: [String: CGImage] = [:]

    static func image(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .semibold, color: UIColor, scale: CGFloat) -> CGImage? {
        let key = "\(name)-\(size)-\(weight.rawValue)-\(color.hashValue)-\(scale)"
        if let cached = cache[key] { return cached }
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        guard let symbol = UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(color, renderingMode: .alwaysOriginal) else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in
            symbol.draw(at: .zero)
        }
        cache[key] = image.cgImage
        return image.cgImage
    }

    /// The size the symbol draws at, in points.
    static func size(of image: CGImage, scale: CGFloat) -> CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }
}
