//
//  Skeleton.swift
//  Cue Studio
//

import SwiftUI

/// A loading shine (04 · Global states, `motion/README.md`): a soft white band crossing a placeholder every 1.4 s, linear. Still under Reduce Motion
/// (a plain placeholder), and paused while the app is not active.
struct SkeletonShine: ViewModifier {
    static let period: TimeInterval = 1.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                    GeometryReader { proxy in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
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

/// A placeholder of a Scripts row (a title bar and a line of meta) at the rows' own size, so nothing jumps when they arrive.
struct ScriptRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.fill).frame(width: 200, height: 14)
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.fill.opacity(0.6)).frame(width: 130, height: 9)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .skeletonShine()
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in ScriptRowSkeleton() } }
        .padding()
        .background(Palette.bg)
}
#endif
