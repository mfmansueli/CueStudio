//
//  CueIcon+TabImage.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The system tab bar draws its icons from images, not views, so the v29 icons (drawn in code, with the stroke at
/// about 1.6 pt at any size) are rasterized here for it: template images, so the bar tints them (yellow when
/// selected), and Record as an image that keeps its two colors.
@MainActor
enum CueTabImage {
    /// A `CueIcon` as a template image `size` points square.
    static func template(_ icon: CueIcon, size: CGFloat = Metrics.tabIconSize) -> UIImage {
        let canvas = CGSize(width: size, height: size)
        let scale = size / CueIconGeometry.grid
        let width = CueIconGeometry.strokeWidth(forSize: size) * scale
        let image = UIGraphicsImageRenderer(size: canvas).image { renderer in
            let context = renderer.cgContext
            UIColor.black.setFill()
            UIColor.black.setStroke()
            for element in CueIconGeometry.elements(for: icon) {
                let path = UIBezierPath(cgPath: element.path.cgPath)
                path.apply(CGAffineTransform(scaleX: scale, y: scale))
                if element.filled { path.fill() }
                if element.stroked {
                    path.lineWidth = width
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    if let dash = element.dash { path.setLineDash(dash.map { $0 * scale }, count: dash.count, phase: 0) }
                    path.stroke()
                }
            }
            context.flush()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    /// Record: a thin ring around a solid red dot. Two colors, so it is not a template.
    static let record: UIImage = {
        let size = Metrics.tabRecordSize
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            let ring = UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: size - 2, height: size - 2))
            ring.lineWidth = 1.5
            UIColor.white.withAlphaComponent(0.75).setStroke()
            ring.stroke()
            let dot = size * 0.56
            UIColor(Palette.record).setFill()
            UIBezierPath(ovalIn: CGRect(x: (size - dot) / 2, y: (size - dot) / 2, width: dot, height: dot)).fill()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }()
}
