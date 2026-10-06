//
//  OnboardingWritingNotice.swift
//  Cue Studio
//

import SwiftUI

/// What the script card says while the first script is written: a star breathing inside a violet halo, "Writing with Apple Intelligence,
/// on this iPhone" with a white shimmer crossing the words every 1.6 s (the same one as the page's writing pill), and the promise that
/// nothing leaves the phone. Still under Reduce Motion.
struct OnboardingWritingNotice: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            // 0 → 1 → 0 every 2.4 s, eased: the star's breath and its halo.
            let pulse = reduceMotion ? 0.5 : 0.5 - 0.5 * cos(time * 2 * .pi / 2.4)
            let sweep = reduceMotion ? 0.5 : 1 - (time.truncatingRemainder(dividingBy: 1.6) / 1.6)
            VStack(spacing: 14) {
                star(pulse: pulse, time: time)
                message(sweep: sweep)
                Text("Written on this iPhone. Nothing leaves it.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.inkHint)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Writing with Apple Intelligence, on this iPhone"))
        .accessibilityIdentifier("onboarding.writingNotice")
    }

    private func star(pulse: Double, time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(Palette.Universe.nightViolet.opacity(0.18 + 0.14 * pulse))
                .frame(width: 54, height: 54)
                .shadow(color: Palette.Universe.nightViolet.opacity(0.55 * pulse), radius: 18)
            Text("✦")
                .font(.system(size: 24))
                .foregroundStyle(Palette.aiTextStrong)
                .scaleEffect(0.92 + 0.16 * pulse)
                .rotationEffect(.degrees(reduceMotion ? 0 : time * 18))
        }
    }

    /// The words in `#E4DEFF` with a white band sliding across.
    private func message(sweep: Double) -> some View {
        let text = Text("Writing with Apple Intelligence, on this iPhone")
            .font(.system(size: 15, weight: .semibold))
            .multilineTextAlignment(.center)
        return text
            .foregroundStyle(Palette.Universe.starLilac)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, sweep - 0.12)),
                        .init(color: .white, location: sweep),
                        .init(color: .clear, location: min(1, sweep + 0.12)),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .mask(text)
            }
    }
}

#if DEBUG
#Preview {
    OnboardingWritingNotice()
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
#endif
