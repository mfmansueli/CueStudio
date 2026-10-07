//
//  StarTransitionOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Draws the star that is the transition from an idea to its script (`IdeaTransitionService`, 09 §8, `motion/README.md`), over the whole
/// app: the star rises to the middle (34% of the height, 0.6 s, `(0.2, 0.8, 0.2, 1)`) while the screen behind darkens (84%); a halo breathes
/// around it and twelve specks gather toward it; "Writing in your voice", the idea and a phrase that changes every 1.6 s sit under it, with
/// Cancel at the bottom. When the script is ready the cover goes solid (0.22 s), the ring opens (0.42 s), the star lands as the caret
/// (0.44 s) and the page writes. Cancel or an error: the star falls 40 pt (0.3 s), the overlay fades (0.22 s).
///
/// Reduce Motion (09 §7): no rise or ring. The overlay fades in (0.2 s) with the text and Cancel in place, then crossfades into the page
/// (0.3 s). The timings are the board's in every situation (`IdeaTransitionService.speed` is 1; only UI tests shorten it).
struct StarTransitionOverlay: View {
    let transition: IdeaTransitionService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Everything that moves is a value that is animated to its place.
    @State private var path: CGFloat = 0
    @State private var starScale: CGFloat = 0.7
    @State private var starFall: CGFloat = 0
    @State private var starOpacity: Double = 1
    @State private var cover: Double = 0
    @State private var halo: Double = 0
    @State private var texts: Double = 0
    @State private var cancelOpacity: Double = 0
    @State private var ring: CGFloat = 0
    @State private var landed: CGFloat = 0
    @State private var showsCaret = false
    @State private var phraseIndex = 0
    /// The request has taken longer than usual: the phrase says so.
    @State private var isTakingLong = false
    @State private var phraseShown = true
    @State private var finishShown = false
    @State private var overlayOpacity: Double = 0
    /// VoiceOver goes to Cancel first (09 §A).
    @AccessibilityFocusState private var cancelHasFocus: Bool

    private var speed: Double { transition.speed }

    var body: some View {
        GeometryReader { proxy in
            if transition.isActive {
                let size = proxy.size
                let origin = proxy.frame(in: .global).origin
                // No arrow to leave from (an idea sent from a sheet): the star rises from the bottom of the screen.
                let from = transition.origin == .zero
                    ? CGPoint(x: size.width / 2, y: size.height - 80)
                    : CGPoint(x: transition.origin.x - origin.x, y: transition.origin.y - origin.y)
                let centre = CGPoint(x: size.width / 2, y: size.height * 0.38)
                let caret = CGPoint(x: Metrics.textGutter + 6, y: proxy.safeAreaInsets.top + 150)
                ZStack(alignment: .topLeading) {
                    coverLayer(size: size, centre: centre)
                    haloLayer(centre: centre)
                    particles(centre: centre)
                    textBlock(size: size, centre: centre)
                    cancelButton(size: size)
                    starLayer(from: from, centre: centre, caret: caret)
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .opacity(overlayOpacity)
                .onAppear { start(from: from, centre: centre) }
                .onChange(of: transition.phase) { _, phase in react(to: phase, size: size, centre: centre, caret: caret) }
                .task(id: transition.phase == .waiting) { await rotatePhrases() }
            }
        }
        .allowsHitTesting(transition.isActive)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Layers

    /// The dark cover. While the ring opens, the cover has a hole growing from the star, so the page shows through it.
    private func coverLayer(size: CGSize, centre: CGPoint) -> some View {
        let diagonal = hypot(size.width, size.height)
        return Rectangle()
            .fill(Palette.Scripts.transitionCover)
            .opacity(cover)
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: ring * diagonal * 2, height: ring * diagonal * 2)
                            .position(centre)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func haloLayer(centre: CGPoint) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            // `cstHalo`: scale .92 ↔ 1.08 and opacity .55 ↔ .9, in a 2.6 s breath.
            let phase = reduceMotion ? 0.5 : 0.5 - 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.6)
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.Scripts.transitionHalo, Palette.Scripts.transitionHalo.opacity(0.24), .clear],
                    center: .center, startRadius: 0, endRadius: 85
                ))
                .frame(width: 170, height: 170)
                .scaleEffect(0.92 + 0.16 * phase)
                .opacity(halo * (0.55 + 0.35 * phase))
                .position(centre)
        }
        .accessibilityHidden(true)
    }

    /// Twelve specks gathering toward the star: each starts 64–134 pt away (in the upper half of the circle) and shrinks into it.
    private func particles(centre: CGPoint) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, _ in
                guard !reduceMotion else { return }
                let time = context.date.timeIntervalSinceReferenceDate
                for index in 0..<12 {
                    let seed = Double(index)
                    let angle = Double.pi * (1.05 + Self.unit(seed * 1.7) * 0.9)
                    let radius = 64 + Self.unit(seed * 3.1) * 70
                    let period = 1.6 + Self.unit(seed * 5.3) * 0.9
                    let t = ((time + seed * 0.37).truncatingRemainder(dividingBy: period)) / period
                    let pull = t * t
                    let point = CGPoint(
                        x: centre.x + cos(angle) * radius * (1 - pull), y: centre.y + sin(angle) * radius * (1 - pull)
                    )
                    let opacity = t < 0.2 ? t / 0.2 * 0.85 : 0.85 * (1 - (t - 0.2) / 0.8)
                    let size = 3 * (1 - 0.7 * pull)
                    let colour = index % 3 == 0 ? Palette.World.skyStarYou : Palette.aiTextStrong
                    canvas.fill(
                        Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)),
                        with: .color(colour.opacity(opacity))
                    )
                }
            }
            .opacity(texts)
        }
        .accessibilityHidden(true)
    }

    /// A repeatable 0…1 from a number, so the specks have their own places without a random generator.
    private static func unit(_ value: Double) -> Double {
        let raw = sin(value * 12.9898) * 43_758.5453
        return raw - raw.rounded(.down)
    }

    private func textBlock(size: CGSize, centre: CGPoint) -> some View {
        VStack(spacing: 8) {
            Text("Writing in your voice")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text("“\(transition.idea)”")
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.86))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 300)
            Text(currentPhrase)
                .font(.system(size: 16, weight: .medium))
                .italic()
                .foregroundStyle(Palette.Scripts.transitionPhrase)
                .opacity(phraseShown ? 1 : 0)
                .offset(y: phraseShown ? 0 : (finishShown ? 0 : 4))
                .frame(height: 22)
                .padding(.top, 4)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .frame(width: size.width)
        .position(x: size.width / 2, y: centre.y + 104 + 36)
        .opacity(texts)
        .offset(y: texts == 1 ? 0 : 8)
    }

    private var currentPhrase: String {
        if finishShown { return IdeaTransitionService.finishPhrase }
        if isTakingLong { return IdeaTransitionService.longWaitPhrase }
        let phrases = IdeaTransitionService.phrases(platform: transition.platformName)
        return phrases[phraseIndex % phrases.count]
    }

    private func cancelButton(size: CGSize) -> some View {
        Button { transition.cancel() } label: {
            Text("Cancel")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 18)
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: size.width / 2, y: size.height - 118 - 22)
        .opacity(cancelOpacity)
        .disabled(transition.phase != .waiting)
        .accessibilityFocused($cancelHasFocus)
        .accessibilityIdentifier("transition.cancel")
    }

    /// The star: it rises along a curve to the middle, breathes while the AI writes, grows at the finish and flies to the caret.
    private func starLayer(from: CGPoint, centre: CGPoint, caret: CGPoint) -> some View {
        let control = CGPoint(x: (from.x + centre.x) / 2 + 40, y: min(from.y, centre.y) - 60)
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || transition.phase != .waiting)) { context in
            // `cstBreath`: 1.4 ↔ 1.65 in 1.6 s while it waits.
            let breath = transition.phase == .waiting && !reduceMotion
                ? 1.4 + 0.25 * (0.5 - 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.6)) : starScale
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Palette.World.skyStarYou.opacity(0.8), radius: 14)
                    .shadow(color: Palette.World.skyStarYou, radius: 1.5)
                    .scaleEffect(breath)
                    .modifier(StarCourse(
                        path: path, landed: landed, from: from, control: control, centre: centre, caret: caret, fall: starFall,
                        flies: !reduceMotion
                    ))
                    .opacity(starOpacity)
                if showsCaret {
                    Capsule()
                        .fill(Palette.acc)
                        .frame(width: 2, height: 22)
                        .shadow(color: Palette.acc.opacity(0.7), radius: 6)
                        .position(x: caret.x, y: caret.y)
                        .phaseAnimator([true, false]) { view, on in view.opacity(on ? 1 : 0) } animation: { _ in .linear(duration: 0.5) }
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Moving

    private func start(from: CGPoint, centre: CGPoint) {
        path = 0
        landed = 0
        ring = 0
        starFall = 0
        starOpacity = 1
        finishShown = false
        phraseIndex = 0
        isTakingLong = false
        phraseShown = true
        showsCaret = false
        texts = 0
        cancelOpacity = 0
        halo = 0
        cover = 0
        starScale = 0.7
        react(to: transition.phase, size: .zero, centre: centre, caret: .zero)
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2 * speed)) { overlayOpacity = 1 }
        } else {
            overlayOpacity = 1
        }
    }

    private func react(to phase: IdeaTransitionService.Phase, size: CGSize, centre: CGPoint, caret: CGPoint) {
        switch phase {
        case .rising: rise()
        case .waiting: wait()
        case .revealing: reveal()
        case .leaving: leave()
        case .idle: overlayOpacity = 0
        }
    }

    /// The star rises to the middle (0.6 s) and the screen darkens to 84% behind it (0.5 s); the halo comes up with it.
    private func rise() {
        if reduceMotion {
            path = 1
            starScale = 1.4
            withAnimation(.easeOut(duration: 0.2 * speed)) {
                cover = 0.84
                halo = 1
                texts = 1
                cancelOpacity = 1
            }
            return
        }
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: IdeaTransitionService.riseDuration * speed)) {
            path = 1
            starScale = 1.4
        }
        withAnimation(.easeOut(duration: 0.5 * speed)) {
            cover = 0.84
            halo = 1
        }
    }

    /// The AI is writing: the words come up (0.4 s, a beat late) and Cancel fades in 0.3 s after them.
    private func wait() {
        // VoiceOver hears what is happening, then each phrase (polite), and starts on Cancel.
        AccessibilityNotification.Announcement(String(localized: "Writing in your voice")).post()
        cancelHasFocus = true
        if reduceMotion { return }
        withAnimation(.easeOut(duration: 0.4 * speed).delay(0.1 * speed)) { texts = 1 }
        withAnimation(.easeOut(duration: 0.3 * speed).delay(0.3 * speed)) { cancelOpacity = 1 }
    }

    /// The script is ready: the finish phrase, the cover goes solid (0.22 s) while the star swells, then the ring opens (0.42 s),
    /// the halo goes and the star flies to the caret (0.44 s, from 2× to 0.6×).
    private func reveal() {
        finishShown = true
        phraseShown = true
        withAnimation(.easeOut(duration: IdeaTransitionService.coverDuration * speed)) {
            texts = 0
            cancelOpacity = 0
            cover = reduceMotion ? 1 : 1
            starScale = reduceMotion ? 1.4 : 2.6
        }
        if reduceMotion {
            // A 0.3 s crossfade into the page, no ring: the cover simply goes.
            withAnimation(.easeOut(duration: 0.3 * speed).delay(IdeaTransitionService.coverDuration * speed)) {
                cover = 0
                halo = 0
                starOpacity = 0
            }
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(IdeaTransitionService.coverDuration * speed))
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: IdeaTransitionService.ringDuration * speed)) {
                ring = 1
                halo = 0
            }
            withAnimation(.timingCurve(0.3, 0.1, 0.25, 1, duration: IdeaTransitionService.landingDuration * speed).delay(0.12 * speed)) {
                landed = 1
                starScale = 0.6
            }
            try? await Task.sleep(for: .seconds((IdeaTransitionService.landingDuration + 0.12) * speed))
            showsCaret = true
            withAnimation(.easeOut(duration: 0.2)) { starOpacity = 0 }
            try? await Task.sleep(for: .seconds(IdeaTransitionService.caretHold * speed))
            showsCaret = false
        }
    }

    /// Cancel or an error: the star falls 40 pt and fades (0.3 s), then the overlay fades (0.22 s).
    private func leave() {
        withAnimation(.easeOut(duration: IdeaTransitionService.fallDuration * speed)) {
            starFall = reduceMotion ? 0 : 40
            starOpacity = 0
            texts = 0
            cancelOpacity = 0
        }
        withAnimation(.easeOut(duration: IdeaTransitionService.leaveFadeDuration * speed).delay(IdeaTransitionService.fallDuration * speed)) {
            cover = 0
            halo = 0
        }
    }

    /// A new phrase every 1.6 s: the old one goes up and out (0.3 s, 4 pt), the new one comes in from 4 pt below.
    private func rotatePhrases() async {
        guard transition.phase == .waiting else { return }
        let count = IdeaTransitionService.phrases(platform: transition.platformName).count
        let clock = ContinuousClock()
        let began = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(IdeaTransitionService.phraseInterval * speed))
            guard !Task.isCancelled, transition.phase == .waiting else { return }
            withAnimation(.easeOut(duration: 0.3 * speed)) { phraseShown = false }
            try? await Task.sleep(for: .seconds(0.3 * speed))
            guard !Task.isCancelled, transition.phase == .waiting else { return }
            // A request that takes long says so once and stays on it (the system gives up on it by itself, and Cancel is there).
            if began.duration(to: clock.now) >= .seconds(IdeaTransitionService.longWait * speed) { isTakingLong = true }
            phraseIndex = (phraseIndex + 1) % max(1, count)
            withAnimation(.easeOut(duration: 0.3 * speed)) { phraseShown = true }
            AccessibilityNotification.Announcement(currentPhrase).post()
        }
    }
}

/// Where the star is: on the curve from the arrow to the middle as `path` goes 0 → 1, then on the line from the middle to the caret as
/// `landed` goes 0 → 1; `fall` pushes it down when it leaves. With Reduce Motion it just sits in the middle.
private struct StarCourse: GeometryEffect {
    var path: CGFloat
    var landed: CGFloat
    let from: CGPoint
    let control: CGPoint
    let centre: CGPoint
    let caret: CGPoint
    var fall: CGFloat
    let flies: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(path, landed), fall) }
        set {
            path = newValue.first.first
            landed = newValue.first.second
            fall = newValue.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let spot: CGPoint
        if !flies {
            spot = centre
        } else if landed > 0 {
            spot = CGPoint(x: centre.x + (caret.x - centre.x) * landed, y: centre.y + (caret.y - centre.y) * landed)
        } else {
            let t = path
            let u = 1 - t
            spot = CGPoint(
                x: u * u * from.x + 2 * u * t * control.x + t * t * centre.x,
                y: u * u * from.y + 2 * u * t * control.y + t * t * centre.y
            )
        }
        return ProjectionTransform(CGAffineTransform(translationX: spot.x - size.width / 2, y: spot.y + fall - size.height / 2))
    }
}
