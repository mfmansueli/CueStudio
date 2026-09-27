//
//  UsageMeter.swift
//  Cue Studio
//

import SwiftUI

/// Thin horizontal meter (quota left, progress through a script).
struct UsageMeter: View {
    /// 0...1
    var fraction: Double
    var color: Color = Palette.acc
    var height: CGFloat = 6
    /// Off for meters that update every frame (scroll progress).
    var animated = true

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.fill)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
        .animation(animated ? .easeOut(duration: 0.3) : nil, value: fraction)
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        UsageMeter(fraction: 0.6)
        UsageMeter(fraction: 0, color: Palette.warn)
    }
    .padding()
    .background(Palette.surface)
}
#endif
