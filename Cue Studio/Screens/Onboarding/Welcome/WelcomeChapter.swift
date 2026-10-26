//
//  WelcomeChapter.swift
//  Cue Studio
//

import SwiftUI

/// 1.1: a star comes in from the top right and lights the dots of a C, arcs down to three words and returns to explode into the last dot;
/// the wordmark, the promise and the button arrive after it (09 §12, `WelcomeScript`). It plays once and holds, the lit dots still shining
/// (their clock keeps running past the end). With Reduce Motion it is the final state only, nothing shining: the C lit, the three words,
/// the wordmark, the title and the button. Its clock stops off screen and while the app is not active (`MotionClock`), and the haptics are
/// beats of that clock, so a call or Control Center in the middle never skips the story ahead.
struct WelcomeChapter: View {
    let plays: Bool
    /// A second of the timeline to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = MotionClock()
    @State private var isOnScreen = false
    /// The centres of the three words in the board's frame, once laid out; the star's last flights go to them.
    @State private var wordCentres: [CGPoint] = []
    @State private var starPath = WelcomeScript.starPath(words: [])
    /// The wordmark, title and words as laid out (`WelcomeLayout`).
    @State private var textHeight: CGFloat = 0

    private nonisolated static let frameSpace = "welcomeFrame"
    private var animates: Bool { plays && frozenAt == nil && !reduceMotion }

    private func runs(onScreen: Bool, phase: ScenePhase) -> Bool { animates && onScreen && phase == .active }

    var body: some View {
        TimelineView(.animation(paused: !runs(onScreen: isOnScreen, phase: scenePhase))) { context in
            let elapsed = clock.elapsed(at: context.date)
            let time = frozenAt ?? (animates ? min(WelcomeScript.finalTime, elapsed) : WelcomeScript.finalTime)
            GeometryReader { proxy in
                let screen = CGSize(
                    width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                )
                let layout = WelcomeLayout(screen: screen, hasHomeIndicator: proxy.safeAreaInsets.bottom > 0, textHeight: textHeight)
                ZStack(alignment: .top) {
                    scene(time, ambient: animates ? elapsed : time, layout: layout)
                    words(time, layout: layout, screenWidth: screen.width)
                    button(time, layout: layout)
                }
                .frame(width: screen.width, height: screen.height, alignment: .top)
                .coordinateSpace(name: Self.frameSpace)
                .ignoresSafeArea()
            }
            .onChange(of: WelcomeScript.beatsPassed(at: time)) { passed, now in
                if animates, now > passed { play(WelcomeScript.orderedBeats[now - 1].beat) }
            }
        }
        .onAppear {
            isOnScreen = true
            clock.setRunning(runs(onScreen: true, phase: scenePhase), at: .now)
        }
        .onDisappear {
            isOnScreen = false
            clock.setRunning(false, at: .now)
        }
        .onChange(of: scenePhase) { _, phase in clock.setRunning(runs(onScreen: isOnScreen, phase: phase), at: .now) }
        .onChange(of: wordCentres) { _, centres in starPath = WelcomeScript.starPath(words: centres) }
    }

    // MARK: - The scene

    /// The board's 390 × 844 frame with the star's scene, centred on the screen and scaled from the top to the room above the words.
    private func scene(_ time: Double, ambient: Double, layout: WelcomeLayout) -> some View {
        let halo = WelcomeScript.halo.pose(at: time)
        return ZStack(alignment: .topLeading) {
            WelcomeShootingStar(time: time)
            Circle()
                .fill(RadialGradient(colors: [Palette.Universe.nightViolet.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: 140))
                .frame(width: 280, height: 280)
                .scaleEffect(halo.scale)
                .opacity(halo.opacity)
                .offset(x: 55, y: 100)
        }
        .frame(width: WelcomeScript.frame.width, height: WelcomeScript.frame.height, alignment: .topLeading)
        .scaleEffect(layout.artScale, anchor: .top)
        // No smaller than nothing: a frame with only a maximum is at least as big as the board inside it, and the 390 × 844 board made the
        // whole chapter that big on an iPhone SE, the button below the bottom edge.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .background { WelcomeStarCanvas(time: time, ambient: ambient, starPath: starPath, scale: layout.artScale) }
    }

    /// The wordmark, the promise and the three words, with the board's spaces between them, where the layout puts them.
    private func words(_ time: Double, layout: WelcomeLayout, screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeWordmark(time: time)
                .frame(maxWidth: .infinity)
            WelcomeTitle(time: time)
                .padding(.top, 60)
            pills(time, layout: layout, screenWidth: screenWidth)
                .padding(.top, 22)
        }
        .padding(.horizontal, 28)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
        .padding(.top, layout.textTop)
        // Type keeps to sizes the board's room can take; past them the words would push the star off the screen.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func pills(_ time: Double, layout: WelcomeLayout, screenWidth: CGFloat) -> some View {
        let words = [
            (String(localized: "TELEPROMPTER"), false), (String(localized: "AUTO CAPTIONS"), false), (String(localized: "✦ AI SCRIPTS"), true),
        ]
        // On one line as on the board; on two when they don't fit it (the largest text sizes), never wider than the screen.
        return FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                WelcomePill(text: word.0, isAI: word.1, hit: WelcomeScript.wordHits[index], time: time)
                    .onGeometryChange(for: CGPoint.self) { proxy in
                        let frame = proxy.frame(in: .named(Self.frameSpace))
                        return CGPoint(x: frame.midX, y: frame.midY)
                    } action: { point in
                        let centre = layout.boardPoint(point, screenWidth: screenWidth)
                        var centres = wordCentres.count == words.count ? wordCentres : Array(repeating: .zero, count: words.count)
                        centres[index] = centre
                        wordCentres = centres
                    }
            }
        }
    }

    // MARK: - The button

    /// "Get started", the only way on: every new creator goes through the first flight (the owner's call). It ends 82 pt above the bottom
    /// edge, where the board has it (48 pt on an iPhone without a Home Indicator).
    private func button(_ time: Double, layout: WelcomeLayout) -> some View {
        let pose = WelcomeScript.primaryButton.pose(at: time)
        return VStack {
            Spacer()
            OnboardingPrimaryButton(title: String(localized: "Get started"), shines: true, identifier: "onboarding.getStarted", action: onStart)
                .opacity(pose.opacity)
                .offset(y: pose.y)
                // Invisible until the opening reaches it: VoiceOver (and a UI test) finds it when it shows.
                .accessibilityHidden(pose.opacity == 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, layout.buttonBottom)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    // MARK: - Time

    /// The haptic of a beat the timeline just passed.
    private func play(_ beat: WelcomeScript.Beat) {
        switch beat {
        case .dot: Haptics.soft()
        case .word: Haptics.apply()
        case .explosion: Haptics.success()
        }
    }
}
