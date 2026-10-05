//
//  DockSurface.swift
//  Cue Studio
//

import SwiftUI

/// The glass of the Scripts dock (09 §2): Liquid Glass in a 28 pt rounded rectangle over two soft auroras (violet from the top left,
/// indigo from the bottom right) on `#1A1840`, with a 0.5 pt violet rim. Clean: no dust, nebula or twinkles inside.
struct DockSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.dockRadius, style: .continuous)
        content
            .background {
                DockAurora().clipShape(shape).accessibilityHidden(true)
            }
            .glassEffect(.regular, in: shape)
            .overlay(shape.strokeBorder(Palette.dockRim, lineWidth: 0.5).allowsHitTesting(false))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 14)
    }
}

extension View {
    /// The Scripts dock's glass.
    func dockSurface() -> some View {
        modifier(DockSurface())
    }
}

/// The two lights of the dock, as ellipses sized by it (CSS `radial-gradient(90% 120% at 0 0, …)` and `(80% 100% at 100% 100%, …)`).
private struct DockAurora: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.dockBase))
            light(&context, size: size, color: Palette.dockAuroraViolet, center: .zero, rx: 0.9, ry: 1.2, stop: 0.6)
            light(&context, size: size, color: Palette.dockAuroraIndigo, center: CGPoint(x: size.width, y: size.height), rx: 0.8, ry: 1.0, stop: 0.65)
        }
    }

    private func light(_ context: inout GraphicsContext, size: CGSize, color: Color, center: CGPoint, rx: Double, ry: Double, stop: Double) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: size.width * rx, y: size.height * ry)
        layer.fill(
            Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
            with: .radialGradient(Gradient(colors: [color, color.opacity(0)]), center: .zero, startRadius: 0, endRadius: stop)
        )
    }
}

#if DEBUG
#Preview {
    Text("Dock").padding(40).dockSurface().padding()
        .background(LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom))
}
#endif
