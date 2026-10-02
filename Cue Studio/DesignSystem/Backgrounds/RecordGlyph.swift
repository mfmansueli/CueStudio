//
//  RecordGlyph.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The camera's record button in miniature: a ring (white in dark, near-black in light, so it
/// reads on either tab bar) around a red dot. Tab bars render SF Symbols as templates (one
/// color), so the glyph is drawn as an image that keeps its colors, one per appearance.
enum RecordGlyph {
    static let darkTabImage = tabImage(ring: .white)
    static let lightTabImage = tabImage(ring: UIColor(hex: 0x1C1C1E))

    static func tabImage(for scheme: ColorScheme) -> UIImage {
        scheme == .dark ? darkTabImage : lightTabImage
    }

    private static func tabImage(ring color: UIColor) -> UIImage {
        let size = CGSize(width: 26, height: 26)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let ring = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 22, height: 22))
            ring.lineWidth = 2
            color.setStroke()
            ring.stroke()
            UIColor(Palette.record).setFill()
            UIBezierPath(ovalIn: CGRect(x: 6, y: 6, width: 14, height: 14)).fill()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1
        )
    }
}
