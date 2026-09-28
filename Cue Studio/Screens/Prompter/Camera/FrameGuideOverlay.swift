//
//  FrameGuideOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Darkens everything outside the recorded frame and marks its edges, so the preview shows exactly
/// what ends up in the video. Only the preview: nothing here is ever recorded.
struct FrameGuideOverlay: View {
    /// The recorded frame, in screen points.
    let frame: CGRect

    var body: some View {
        Canvas { context, size in
            var outside = Path(CGRect(origin: .zero, size: size))
            outside.addRect(frame)
            context.fill(outside, with: .color(Palette.frameMask), style: FillStyle(eoFill: true))

            var edges = Path()
            for y in [frame.minY, frame.maxY] where y > 0.5 && y < size.height - 0.5 {
                edges.move(to: CGPoint(x: frame.minX, y: y))
                edges.addLine(to: CGPoint(x: frame.maxX, y: y))
            }
            for x in [frame.minX, frame.maxX] where x > 0.5 && x < size.width - 0.5 {
                edges.move(to: CGPoint(x: x, y: frame.minY))
                edges.addLine(to: CGPoint(x: x, y: frame.maxY))
            }
            context.stroke(edges, with: .color(Palette.frameEdge), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
