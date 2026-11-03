//
//  TextWindowResizeHandle.swift
//  Cue Studio
//

import SwiftUI

/// The corner of the Selfie text window: drag it to make the window wider, narrower, taller or
/// shorter (it stays centered), double-tap to put the original size back. While the finger is
/// down the window gets a yellow outline, and nothing else: the window's own size says it (owner, 02/11/2026: the
/// "WIDTH · LINES" label above it hid under the top bar). The mark is a thick arc around the outside of the window's
/// rounded corner, following its curve.
struct TextWindowResizeHandle: View {
    let viewModel: PrompterViewModel
    let layout: ReadingLayout
    @Binding var isResizing: Bool

    @State private var start: (width: Double, height: Double)?
    @State private var resize: TextWindowResize?

    private static let target: CGFloat = 44
    /// The arc's gap from the window's edge and its thickness.
    private static let gap: CGFloat = 5
    private static let thickness: CGFloat = 4
    /// The arc's radius: the window's corner, grown by the gap and half the stroke, so it sits around the corner.
    private static var arcRadius: CGFloat { Metrics.cardRadius + gap + thickness / 2 }

    var body: some View {
        let rect = layout.windowRect
        ZStack {
            if resize != nil {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.acc, lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
            // The touch target is centered on the arc's middle, at 45° around the corner.
            let center = CGPoint(x: rect.maxX - Metrics.cardRadius, y: rect.maxY - Metrics.cardRadius)
            let reach = Self.arcRadius * CGFloat(0.5).squareRoot()
            handle.position(x: center.x + reach, y: center.y + reach)
        }
        .ignoresSafeArea()
    }

    private var handle: some View {
        CornerArc(radius: Self.arcRadius)
            .stroke(Palette.acc, style: StrokeStyle(lineWidth: Self.thickness, lineCap: .round))
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
            .frame(width: Self.target, height: Self.target)
            .contentShape(Rectangle())
            .gesture(drag)
            .simultaneousGesture(TapGesture(count: 2).onEnded { viewModel.resetTextWindow() })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Resize text window"))
            .accessibilityValue(Text(accessibilityValue))
            .accessibilityHint(Text("Drag to resize. Double-tap to reset."))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: viewModel.nudgeTextWindowHeight(byLines: 1)
                case .decrement: viewModel.nudgeTextWindowHeight(byLines: -1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: Text("Reset text window")) { viewModel.resetTextWindow() }
            .accessibilityIdentifier("prompter.textWindowResizeHandle")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let from = start ?? (viewModel.session.prompter.readingWidth, viewModel.session.prompter.textWindowHeight)
                if start == nil {
                    start = from
                    isResizing = true
                }
                resize = viewModel.resizeTextWindow(from: from, by: value.translation)
            }
            .onEnded { _ in
                start = nil
                resize = nil
                isResizing = false
            }
    }

    private var accessibilityValue: String {
        let prompter = viewModel.session.prompter
        let lines = max(1, Int((prompter.textWindowHeight / (prompter.size * prompter.lineSpacing)).rounded()))
        return String(localized: "\(Int((prompter.readingWidth * 100).rounded())) percent wide, \(lines) lines")
    }
}

extension TextWindowResizeHandle {
    /// The arc around the window's bottom-right corner, drawn in a frame centered on its middle (45°): the circle's center is the
    /// corner's, up and to the left of the frame's center by the radius at 45°. A short stretch of the quarter, 50° around its
    /// middle (owner, 02/11/2026: shorter and thinner).
    private nonisolated struct CornerArc: Shape {
        let radius: CGFloat

        func path(in rect: CGRect) -> Path {
            let reach = radius * CGFloat(0.5).squareRoot()
            let center = CGPoint(x: rect.midX - reach, y: rect.midY - reach)
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .degrees(20), endAngle: .degrees(70), clockwise: false)
            return path
        }
    }
}
