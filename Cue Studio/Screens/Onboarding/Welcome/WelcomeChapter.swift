//
//  WelcomeChapter.swift
//  Cue Studio
//

import SwiftUI

/// 1.1: a star comes in from the top right and lights the dots of a C, arcs down to three words and returns to explode into the last dot;
/// the wordmark, the promise and the buttons arrive after it (09 §12, `WelcomeScript`). It plays once and holds. With Reduce Motion it
/// is the final state only: the C lit, the three words, the wordmark, the title and the buttons.
struct WelcomeChapter: View {
    let plays: Bool
    /// A second of the timeline to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    let onStart: () -> Void
    let onReturning: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var isFinished = false
    /// The centres of the three words in the board's frame, once laid out; the star's last flights go to them.
    @State private var wordCentres: [CGPoint] = []
    @State private var starPath = WelcomeScript.starPath(words: [])

    private nonisolated static let frameSpace = "welcomeFrame"
    private var animates: Bool { plays && frozenAt == nil && !reduceMotion }

    var body: some View {
        TimelineView(.animation(paused: !animates || isFinished)) { context in
            let time = frozenAt ?? (animates ? min(WelcomeScript.finalTime, context.date.timeIntervalSince(start)) : WelcomeScript.finalTime)
            ZStack {
                scene(time)
                    .ignoresSafeArea()
                buttons(time)
            }
        }
        .task(id: animates) { await run() }
        .onChange(of: wordCentres) { _, centres in starPath = WelcomeScript.starPath(words: centres) }
    }

    // MARK: - The scene

    /// The board's 390 × 844 frame, centred on the screen, from the top.
    private func scene(_ time: Double) -> some View {
        let halo = WelcomeScript.halo.pose(at: time)
        return ZStack(alignment: .topLeading) {
            WelcomeShootingStar(time: time)
            Circle()
                .fill(RadialGradient(colors: [Palette.nightViolet.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: 140))
                .frame(width: 280, height: 280)
                .scaleEffect(halo.scale)
                .opacity(halo.opacity)
                .offset(x: 55, y: 100)
            WelcomeWordmark(time: time)
                .frame(width: WelcomeScript.frame.width)
                .offset(y: 350)
            WelcomeTitle(time: time)
                .padding(.horizontal, 28)
                .frame(width: WelcomeScript.frame.width, alignment: .leading)
                .offset(y: 430)
            pills(time)
                .padding(.horizontal, 28)
                .frame(width: WelcomeScript.frame.width, alignment: .leading)
                .offset(y: 652)
        }
        .frame(width: WelcomeScript.frame.width, height: WelcomeScript.frame.height, alignment: .topLeading)
        .coordinateSpace(name: Self.frameSpace)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { WelcomeStarCanvas(time: time, starPath: starPath) }
    }

    private func pills(_ time: Double) -> some View {
        let words = [
            (String(localized: "TELEPROMPTER"), false), (String(localized: "AUTO CAPTIONS"), false), (String(localized: "✦ AI SCRIPTS"), true),
        ]
        return HStack(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                WelcomePill(text: word.0, isAI: word.1, hit: WelcomeScript.wordHits[index], time: time)
                    .onGeometryChange(for: CGPoint.self) { proxy in
                        let frame = proxy.frame(in: .named(Self.frameSpace))
                        return CGPoint(x: frame.midX, y: frame.midY)
                    } action: { centre in
                        var centres = wordCentres.count == words.count ? wordCentres : Array(repeating: .zero, count: words.count)
                        centres[index] = centre
                        wordCentres = centres
                    }
            }
        }
        .fixedSize()
    }

    // MARK: - The buttons

    private func buttons(_ time: Double) -> some View {
        let primary = WelcomeScript.primaryButton.pose(at: time)
        let secondary = WelcomeScript.secondaryButton.pose(at: time)
        // As the board has them: the yellow one ends 82 pt above the bottom edge, the quiet one 32 below it (its 44 pt target ends at 812, so
        // the bottom 34 pt of the screen stay free of controls).
        return VStack(spacing: 6) {
            Spacer()
            OnboardingPrimaryButton(title: String(localized: "Get started"), shines: true, identifier: "onboarding.getStarted", action: onStart)
                .opacity(primary.opacity)
                .offset(y: primary.y)
                // Invisible until the opening reaches them: VoiceOver (and a UI test) finds them when they show.
                .accessibilityHidden(primary.opacity == 0)
            OnboardingSecondaryButton(title: String(localized: "I already use Cue"), identifier: "onboarding.returning", action: onReturning)
                .opacity(secondary.opacity)
                .offset(y: secondary.y)
                .accessibilityHidden(secondary.opacity == 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Time

    /// The haptics, each at its second, and the end of the timeline.
    private func run() async {
        guard animates else { return }
        start = .now
        isFinished = false
        for (second, beat) in WelcomeScript.beats {
            let wait = second - Date.now.timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled { return }
            switch beat {
            case .dot: Haptics.soft()
            case .word: Haptics.apply()
            case .explosion: Haptics.success()
            }
        }
        try? await Task.sleep(for: .seconds(max(0, WelcomeScript.finalTime + 0.2 - Date.now.timeIntervalSince(start))))
        isFinished = true
    }
}
