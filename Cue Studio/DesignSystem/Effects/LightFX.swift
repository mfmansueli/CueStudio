//
//  LightFX.swift
//  Cue Studio
//

import SwiftUI

/// The small lights the boards draw on every landing and birth, for a scene's `Canvas`: a cross of light and a ring, which read their size,
/// turn and fade from a `MotionPose` (the board's own layer at the second being drawn), so the scene only says where and in what colour; and
/// the disc they are made of.
enum LightFX {
    /// A four-point cross of light `size` across (its upright is `verticalRatio` of it), opening and closing with the pose's scale and turning
    /// with its rotation.
    static func cross(
        at centre: CGPoint, size: CGFloat, thickness: CGFloat = 1.8, verticalRatio: CGFloat = 0.6, pose: MotionPose, color: Color,
        glow: Color? = nil, in context: inout GraphicsContext
    ) {
        guard pose.opacity > 0.01, pose.sx > 0.01 else { return }
        var layer = context
        layer.opacity = pose.opacity
        layer.translateBy(x: centre.x, y: centre.y)
        layer.rotate(by: .degrees(pose.rot))
        layer.scaleBy(x: pose.sx, y: pose.sx)
        if let glow { layer.addFilter(.shadow(color: glow, radius: 3)) }
        func fade(_ start: CGPoint, _ end: CGPoint) -> GraphicsContext.Shading {
            .linearGradient(
                Gradient(stops: [
                    .init(color: color.opacity(0), location: 0), .init(color: color.opacity(0.45), location: 0.3), .init(color: color, location: 0.5),
                    .init(color: color.opacity(0.45), location: 0.7), .init(color: color.opacity(0), location: 1),
                ]),
                startPoint: start, endPoint: end
            )
        }
        let bar = CGRect(x: -size / 2, y: -thickness / 2, width: size, height: thickness)
        layer.fill(Path(roundedRect: bar, cornerRadius: thickness / 2), with: fade(CGPoint(x: bar.minX, y: 0), CGPoint(x: bar.maxX, y: 0)))
        let post = CGRect(x: -thickness / 2, y: -size * verticalRatio / 2, width: thickness, height: size * verticalRatio)
        layer.fill(Path(roundedRect: post, cornerRadius: thickness / 2), with: fade(CGPoint(x: 0, y: post.minY), CGPoint(x: 0, y: post.maxY)))
    }

    /// A thin ring that opens where something lands: `radius` at scale 1, drawn at the pose's scale and fade.
    static func ring(
        _ pose: MotionPose, at centre: CGPoint, radius: CGFloat, color: Color, lineWidth: CGFloat = 1.5, in context: inout GraphicsContext
    ) {
        guard pose.opacity > 0.01, pose.sx > 0.001 else { return }
        context.stroke(disc(centre, radius * pose.sx), with: .color(color.opacity(pose.opacity)), lineWidth: lineWidth)
    }

    static func disc(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }
}
