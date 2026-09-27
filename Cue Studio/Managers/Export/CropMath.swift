//
//  CropMath.swift
//  Cue Studio
//

import CoreGraphics

/// Geometry for cropping takes to their frame. Pure so it can be tested without video.
nonisolated enum CropMath {
    /// Largest centered rectangle with `aspect` (width / height) inside `size`, with even
    /// dimensions because video encoders require them.
    static func centeredCrop(in size: CGSize, aspect: Double) -> CGRect {
        guard size.width > 0, size.height > 0, aspect > 0 else { return .zero }
        let frameAspect = size.width / size.height
        if frameAspect > aspect {
            let width = even(size.height * aspect)
            let height = even(size.height)
            return CGRect(x: ((size.width - width) / 2).rounded(.down), y: 0, width: width, height: height)
        } else {
            let width = even(size.width)
            let height = even(size.width / aspect)
            return CGRect(x: 0, y: ((size.height - height) / 2).rounded(.down), width: width, height: height)
        }
    }

    static func even(_ value: CGFloat) -> CGFloat {
        (value / 2).rounded(.down) * 2
    }
}
