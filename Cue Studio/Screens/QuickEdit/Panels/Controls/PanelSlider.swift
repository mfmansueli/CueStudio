//
//  PanelSlider.swift
//  Cue Studio
//

import SwiftUI

/// A slider with its name and value: a thin track, the fill in yellow (from the middle for
/// −100…+100 settings) and a white knob. A drag is one undo step (`onEditingChanged`); VoiceOver
/// adjusts it by `step`.
struct PanelSlider: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// Filled from the middle (Exposure, Contrast…).
    var bipolar = false
    let format: PanelValueFormat
    let identifier: String
    let onChange: (Double) -> Void
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(.subheadline, weight: .semibold))
                Spacer()
                Text(format.text(value))
                    .font(.system(.subheadline).monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let zero = bipolar ? (0 - range.lowerBound) / (range.upperBound - range.lowerBound) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.sliderTrack).frame(height: 4)
                    Capsule().fill(Palette.acc)
                        .frame(width: max(0, abs(fraction - zero) * width), height: 4)
                        .offset(x: min(fraction, zero) * width)
                    Circle().fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: Palette.textShadow, radius: 2.5, y: 1)
                        .offset(x: fraction * width - 12)
                }
                .frame(height: 30)
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
            .frame(height: 30)
        }
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
