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
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion, scenePhase == .active {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    GeometryReader { proxy in
                        let phase = Self.phase(at: context.date.timeIntervalSinceReferenceDate, interval: interval)
                        if let phase {
                            let width = proxy.size.width + 140
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: 70, height: proxy.size.height * 2)
                                .rotationEffect(.degrees(15))
                                .position(x: -70 + width * phase, y: proxy.size.height / 2)
                        }
                    }
                }
                .clipShape(shape)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

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
