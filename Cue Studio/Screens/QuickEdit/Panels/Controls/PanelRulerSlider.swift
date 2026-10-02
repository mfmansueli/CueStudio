//
//  PanelRulerSlider.swift
//  Cue Studio
//

import SwiftUI

/// A slider drawn as a ruler: ticks above a thin track, the fill in yellow (from the middle for
/// −100…+100 settings) and a white knob. It's the one control of Adjust, which picks the setting
/// above it. A drag is one undo step (`onEditingChanged`); VoiceOver adjusts it by `step`.
struct PanelRulerSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// Filled from the middle.
    var bipolar = false
    let format: PanelValueFormat
    let identifier: String
    let onChange: (Double) -> Void
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isDragging = false

    private static let tickCount = 40
    private static let knobSize: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let span = range.upperBound - range.lowerBound
            let fraction = (value - range.lowerBound) / span
            let zero = bipolar ? (0 - range.lowerBound) / span : 0
            ZStack(alignment: .topLeading) {
                ForEach(0...Self.tickCount, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(index % 10 == 0 ? 0.55 : 0.25))
                        .frame(width: 1, height: index % 10 == 0 ? 14 : index % 5 == 0 ? 10 : 6)
                        .offset(x: width * CGFloat(index) / CGFloat(Self.tickCount), y: 6)
                }
                Capsule().fill(Palette.sliderTrack)
                    .frame(width: width, height: 6)
                    .offset(y: 32)
                Capsule().fill(Palette.acc)
                    .frame(width: max(0, abs(fraction - zero) * width), height: 6)
                    .offset(x: min(fraction, zero) * width, y: 32)
                if bipolar {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Palette.ink2)
                        .frame(width: 2, height: 16)
                        .offset(x: width * zero - 1, y: 27)
                }
                Circle().fill(Color.white)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .shadow(color: Palette.textShadow, radius: 4, y: 2)
                    .offset(x: fraction * width - Self.knobSize / 2, y: 21)
            }
            .frame(width: width, height: 56, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        onChange(snapped(at: drag.location.x, width: width))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 56)
        // The ends of the knob's travel sit at the ends of the ruler, a little inside the panel.
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(format.text(value)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(range.upperBound, value + step))
            case .decrement: onChange(max(range.lowerBound, value - step))
            @unknown default: break
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func snapped(at x: CGFloat, width: CGFloat) -> Double {
        let fraction = min(max(Double(x / max(1, width)), 0), 1)
        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        return min(max((raw / step).rounded() * step, range.lowerBound), range.upperBound)
    }
}
