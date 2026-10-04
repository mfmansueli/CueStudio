//
//  CueSlider.swift
//  Cue Studio
//

import SwiftUI

/// The v26 slider: a 4 pt track filled in yellow and a 24 pt white thumb, 44 pt tall to touch. Used
/// where the control sits on the video (the recorder's speed). It is one adjustable element for
/// VoiceOver: swipe up or down to change it by a step.
struct CueSlider: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.1
    /// What VoiceOver reads as the value ("0.7×").
    let valueText: String
    var identifier: String?
    let onChange: (Double) -> Void

    private static let thumbSize: CGFloat = 24
    private static let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let travel = max(0, proxy.size.width - Self.thumbSize)
            let offset = travel * CueSliderMath.fraction(of: value, in: range)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.sliderTrack)
                    .frame(height: Self.trackHeight)
                Capsule()
                    .fill(Palette.accText)
                    .frame(width: Self.thumbSize / 2 + offset, height: Self.trackHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                    .offset(x: offset)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let next = CueSliderMath.value(
                        atX: drag.location.x, width: proxy.size.width, thumb: Self.thumbSize, range: range, step: step
                    )
                    if next != value { onChange(next) }
                }
            )
        }
        .frame(height: Metrics.hitTarget)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(valueText))
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? step : -step
            let next = CueSliderMath.snapped(value + delta, step: step, in: range)
            if next != value { onChange(next) }
        }
        .accessibilityIdentifier(identifier ?? "")
    }
}

#if DEBUG
#Preview {
    @Previewable @State var speed = 0.7
    CueSlider(title: "Speed", value: speed, range: 0.3...2, valueText: "\(speed)×", onChange: { speed = $0 })
        .padding()
        .background(Color.black)
}
#endif
