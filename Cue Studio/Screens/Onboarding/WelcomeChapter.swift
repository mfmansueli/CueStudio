//
//  WelcomeChapter.swift
//  Cue Studio
//

import SwiftUI

/// 1.1: the stars arrive, the constellation draws itself, the Cue star lights and the promise rises out of
/// the blur: "Every creator has a universe to share."
struct WelcomeChapter: View {
    let onStart: () -> Void
    let onReturning: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var ignite = 0
    @State private var textShown = false
    @State private var buttonsShown = false

    /// The constellation, in 0...1 of its square. The last point is the Cue star.
    private let points: [CGPoint] = [
        CGPoint(x: 0.78, y: 0.22), CGPoint(x: 0.5, y: 0.2), CGPoint(x: 0.22, y: 0.38),
        CGPoint(x: 0.28, y: 0.62), CGPoint(x: 0.52, y: 0.82), CGPoint(x: 0.82, y: 0.7),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 20)
            constellation
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .accessibilityHidden(true)
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 16) {
                Text("CUE STUDIO")
                    .font(CueStudioFont.hud)
                    .tracking(1.6)
                    .foregroundStyle(Palette.accText)
                Text("Every creator has a universe to share.")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.7)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .blur(radius: textShown || reduceMotion ? 0 : 10)
                    .offset(y: textShown || reduceMotion ? 0 : 16)
                    .opacity(textShown ? 1 : 0)
                    .accessibilityAddTraits(.isHeader)
                Text("Write it, say it on camera, and send it further. Script, teleprompter, captions and edit in one place.")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(textShown ? 1 : 0)
                HStack(spacing: 8) {
                    pill(String(localized: "TELEPROMPTER"))
                    pill(String(localized: "AUTO CAPTIONS"))
                    pill(String(localized: "✦ AI SCRIPTS"), isAI: true)
                }
                .opacity(buttonsShown ? 1 : 0)
            }
            .padding(.horizontal, 20)
            VStack(spacing: 2) {
                OnboardingPrimaryButton(title: String(localized: "Get started"), shines: true, identifier: "onboarding.getStarted", action: onStart)
                OnboardingSecondaryButton(title: String(localized: "I already use Cue"), identifier: "onboarding.returning", action: onReturning)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)
            .opacity(buttonsShown ? 1 : 0)
        }
        .onAppear(perform: play)
    }

    private func pill(_ text: String, isAI: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(isAI ? Palette.aiTextStrong : Palette.ink2)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(isAI ? Palette.aiFill : Palette.overlayFill, in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var constellation: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let place = { (point: CGPoint) in CGPoint(x: point.x * size.width, y: point.y * size.height) }
            ZStack {
                Path { path in
                    path.move(to: place(points[0]))
                    for point in points.dropFirst() { path.addLine(to: place(point)) }
                }
                .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(points.dropLast().enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .shadow(color: .white.opacity(0.6), radius: 5)
                        .scaleEffect(drawn || reduceMotion ? 1 : 0.01)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.15 * Double(index)), value: drawn)
                        .position(place(point))
                }
                // The Cue star: yellow, with its ring, lit last.
                ZStack {
                    Circle().strokeBorder(Palette.acc.opacity(0.7), lineWidth: 1.5).frame(width: 52, height: 52)
                    Circle().fill(Palette.acc.opacity(0.25)).frame(width: 36, height: 36)
                    IgniteEffect(trigger: ignite, diameter: 14)
                }
                .opacity(drawn || reduceMotion ? 1 : 0)
                .position(place(points[points.count - 1]))
            }
        }
    }

    private func play() {
        guard !reduceMotion else {
            drawn = true; ignite = 1; textShown = true; buttonsShown = true
            return
        }
        withAnimation(.easeInOut(duration: 1.6).delay(0.3)) { drawn = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1700))
            ignite += 1
            Haptics.success()
            withAnimation(CueMotion.light(duration: 0.9)) { textShown = true }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.5)) { buttonsShown = true }
        }
    }
}
