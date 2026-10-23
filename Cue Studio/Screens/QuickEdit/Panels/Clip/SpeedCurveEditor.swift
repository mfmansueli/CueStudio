//
//  SpeedCurveEditor.swift
//  Cue Studio
//

import SwiftUI

/// The picked clip's speed curve, to shape: the curve over a 1× line, its points as handles (up speeds up, down slows down; the
/// ones inside also slide sideways), and the playhead. VoiceOver: each point is adjustable (faster, slower).
struct SpeedCurveEditor: View {
    let viewModel: QuickEditViewModel
    let curve: SpeedCurve
    /// The size the editor had when the drag started, so the drag reads its own coordinates.
    @State private var dragged: Int?

    static let height: CGFloat = 132

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                grid(size: size)
                SpeedCurveGlyph(curve: curve, color: Palette.acc)
                if let position = viewModel.curvePlayheadPosition {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(width: 2, height: size.height)
                        .offset(x: size.width * position - 1)
                        .accessibilityHidden(true)
                }
                ForEach(Array(curve.points.enumerated()), id: \.offset) { index, point in
                    handle(index: index, point: point, size: size)
                }
            }
        }
        .frame(height: Self.height)
        .padding(.vertical, 6)
        // Time runs left to right in every language (media never mirrors), like the timeline.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func grid(size: CGSize) -> some View {
        Canvas { context, _ in
            for speed in [0.25, 0.5, 1, 2, 4] {
                let y = Self.y(forSpeed: speed, height: size.height)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(speed == 1 ? Palette.ink3 : Palette.Editor.separator), lineWidth: speed == 1 ? 1 : 0.5)
            }
        }
        .overlay(alignment: .topLeading) {
            ForEach([4.0, 1, 0.25], id: \.self) { speed in
                Text(SpeedScale.label(forMultiple: speed))
                    .monoFont(.caption2)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize()
                    .position(x: 22, y: Self.y(forSpeed: speed, height: size.height) - 8)
            }
            .accessibilityHidden(true)
        }
    }

    private func handle(index: Int, point: SpeedCurve.Point, size: CGSize) -> some View {
        let center = CGPoint(x: size.width * point.position, y: Self.y(forSpeed: point.speed, height: size.height))
        return Circle()
            .fill(dragged == index ? Palette.acc : Palette.ink)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(Palette.acc, lineWidth: 2))
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .position(center)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if dragged == nil {
                            dragged = index
                            viewModel.beginCurveDrag()
                        }
                        let speed = Self.speed(forY: value.location.y, height: size.height)
                        viewModel.moveCurvePoint(index, to: speed, position: Double(value.location.x / max(1, size.width)))
                    }
                    .onEnded { _ in
                        dragged = nil
                        viewModel.endCurveDrag()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Point \(index + 1) of \(curve.points.count)"))
            .accessibilityValue(Text(SpeedScale.label(forMultiple: point.speed)))
            .accessibilityAdjustableAction { direction in
                let factor = direction == .increment ? 1.25 : 0.8
                viewModel.moveCurvePoint(index, to: point.speed * factor)
            }
            .accessibilityIdentifier("edit.speed.curvePoint.\(index)")
    }

    /// Where a speed sits on the editor, from the top: 4× at the top, 0.25× at the bottom, 1× in the middle.
    static func y(forSpeed speed: Double, height: CGFloat) -> CGFloat {
        let range = SpeedCurve.speedRange
        let share = (log(range.upperBound) - log(min(max(speed, range.lowerBound), range.upperBound))) / (log(range.upperBound) - log(range.lowerBound))
        return height * CGFloat(share)
    }

    static func speed(forY y: CGFloat, height: CGFloat) -> Double {
        let range = SpeedCurve.speedRange
        let share = min(max(Double(y / max(1, height)), 0), 1)
        return exp(log(range.upperBound) - share * (log(range.upperBound) - log(range.lowerBound)))
    }
}
