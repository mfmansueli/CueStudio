//
//  ShineSweep.swift
//  Cue Studio
//

import SwiftUI

/// A white band, 70 pt wide, tilted 105°, that sweeps across a primary button in 0.8 s every 4 to 8 s. At
/// most one element of a screen should have it. Not shown under Reduce Motion.
struct ShineSweep<S: Shape>: ViewModifier {
    var shape: S
    /// Seconds between sweeps.
    var interval: Double = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // Draw inside one fixed canvas: a moving child view can enlarge its button's accessibility frame past the clipped pill.
        content.overlay {
            if !reduceMotion {
                AmbientTimeline { ambient in
                    Canvas { context, size in
                        guard let phase = Self.phase(at: ambient.seconds + interval - Self.firstSweep, interval: interval) else { return }
                        let bandWidth: CGFloat = 70
                        context.translateBy(x: -bandWidth + (size.width + bandWidth * 2) * phase, y: size.height / 2)
                        context.rotate(by: .degrees(15))
                        context.fill(
                            Path(CGRect(x: -bandWidth / 2, y: -size.height, width: bandWidth, height: size.height * 2)),
                            with: .linearGradient(
                                Gradient(colors: [.white.opacity(0), .white.opacity(Self.peakOpacity), .white.opacity(0)]),
                                startPoint: CGPoint(x: -bandWidth / 2, y: 0), endPoint: CGPoint(x: bandWidth / 2, y: 0)
                            )
                        )
                    }
                }
                .clipShape(shape)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    /// Seconds from the button appearing to its first sweep: it arrives first, then shines.
    static var firstSweep: Double { 1.2 }

    /// The band crosses the ink too: its brightest point must keep 4.5:1, measured in PaletteContrastTests.
    static var peakOpacity: Double { 0.35 }

    /// 0...1 while a sweep is crossing, nil in between.
    static func phase(at time: TimeInterval, interval: Double) -> Double? {
        let moment = time.truncatingRemainder(dividingBy: interval)
        guard moment < CueMotion.Duration.shineSweep else { return nil }
        return moment / CueMotion.Duration.shineSweep
    }
}

extension View {
    /// A shine that sweeps over this (yellow) button every few seconds.
    func shineSweep<S: Shape>(in shape: S = Capsule(), interval: Double = 6) -> some View {
        modifier(ShineSweep(shape: shape, interval: interval))
    }
}
