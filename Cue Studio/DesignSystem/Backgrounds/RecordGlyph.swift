//
//  RecordGlyph.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The camera's record button in miniature: a white ring around a red dot. Tab bars render SF
/// Symbols as templates (one color), so the glyph is drawn as an image that keeps its colors.
enum RecordGlyph {
    static let tabImage: UIImage = {
        let size = CGSize(width: 26, height: 26)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let ring = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 22, height: 22))
            ring.lineWidth = 2
            UIColor.white.setStroke()
            ring.stroke()
            UIColor(Palette.record).setFill()
            UIBezierPath(ovalIn: CGRect(x: 6, y: 6, width: 14, height: 14)).fill()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }()
}
