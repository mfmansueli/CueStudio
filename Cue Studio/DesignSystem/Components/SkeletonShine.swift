//
//  SkeletonShine.swift
//  Cue Studio
//

import SwiftUI

/// A loading shine (04 · Global states, `motion/README.md`): a soft white band crossing a placeholder every 1.4 s, linear. Still under Reduce Motion
/// (a plain placeholder), and paused while the app is not active.
struct SkeletonShine: ViewModifier {
    static let period: TimeInterval = 1.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                AmbientTimeline { ambient in
                    GeometryReader { proxy in
                        let phase = ambient.seconds.truncatingRemainder(dividingBy: Self.period) / Self.period
                        LinearGradient(colors: [.clear, .white.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.6)
                            .offset(x: proxy.size.width * (phase * 1.6 - 0.6))
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
    }
}

extension View {
    /// The shine of a placeholder that stands for what is loading.
    func skeletonShine() -> some View {
        modifier(SkeletonShine())
    }
}
