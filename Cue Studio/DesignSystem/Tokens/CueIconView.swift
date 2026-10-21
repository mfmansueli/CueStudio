//
//  CueIconView.swift
//  Cue Studio
//

import SwiftUI

/// An icon at a size, tinted by the foreground style: `CueIconView(.speed, size: 22)`. The stroke is 1.6 pt
/// at any size (`CueIconGeometry.strokeWidth(forSize:)`). `isFilled` fills the closed shapes too, for a state
/// that is "on" (the best take, once marked).
struct CueIconView: View {
    let icon: CueIcon
    var size: CGFloat = 24
    var isFilled = false

    init(_ icon: CueIcon, size: CGFloat = 24, isFilled: Bool = false) {
        self.icon = icon
        self.size = size
        self.isFilled = isFilled
    }

    var body: some View {
        let elements = CueIconGeometry.elements(for: icon)
        let width = CueIconGeometry.strokeWidth(forSize: size)
        let hasShell = elements.contains { $0.closed && $0.stroked }
        Canvas { context, canvasSize in
            let scale = canvasSize.width / CueIconGeometry.grid
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            // In a layer, so a detail of a filled icon (the star in a marked best take) can be knocked out of
            // the fill without erasing what is behind the icon.
            context.drawLayer { layer in
                for element in elements {
                    let path = element.path.applying(transform)
                    layer.opacity = element.opacity
                    if element.filled, isFilled, hasShell, !element.stroked {
                        layer.blendMode = .destinationOut
                        layer.fill(path, with: .color(.black))
                        layer.blendMode = .normal
                        continue
                    }
                    if element.filled || (isFilled && element.closed) {
                        layer.fill(path, with: .foreground)
                    }
                    if element.stroked {
                        let dash = element.dash.map { $0.map { $0 * scale } } ?? []
                        layer.stroke(
                            path, with: .foreground,
                            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
                        )
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
