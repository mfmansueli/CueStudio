//
//  StarTransitionOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Draws the star that is the transition from an idea to its script (`IdeaTransitionService`, 09 §8, `motion/README.md`), over the whole
/// app: the star rises to the middle (34% of the height, 0.6 s, `(0.2, 0.8, 0.2, 1)`) while the screen behind darkens (84%); a halo breathes
/// around it and twelve specks gather toward it; "Drafting in your voice", the idea, a phrase that changes every 1.6 s and how much of the script
/// is written ("42%", an estimate: `WritingProgressEstimate`) sit under it, with Cancel at the bottom. When the script is ready the cover goes
/// solid (0.22 s), the ring opens (0.42 s), the star lands as the caret (0.44 s) and the page writes. Cancel or an error: the star falls 40 pt
/// (0.3 s), the overlay fades (0.22 s).
///
/// Layered over the board's sequence: as the star leaves, the idea's words come apart into a stream of light that runs into it (`dust`);
/// it ignites where it stops (a flash and a ring of light, with the end of the takeoff's haptic); an orbit round it closes as the script
/// is written (`ProgressOrbit`), with a light tick at each quarter; flying to the caret it leaves a comet's streak (`CometTrail`), lands
/// with its haptic, and a light crosses the page once. Slower than the board's (the owner's call, 20/10/2026: the effects should be seen;
/// the script is written behind them all the while): the rise 1.1 s, the ring 0.8 s, the landing 0.9 s.
///
/// Reduce Motion (09 §7): no rise or ring, no stream, flash, streak or light. The overlay fades in (0.2 s) with the text and Cancel in
/// place, then crossfades into the page (0.3 s). The timings are the board's in every situation (`IdeaTransitionService.speed` is 1; only UI tests shorten it).
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
    /// When the idea's stream of light started (the tap); nil once it has run into the star.
    @State private var dustStart: Date?
    /// The star igniting where it stops, 0 → 1.
    @State private var ignition: CGFloat = 0
    /// The light crossing the page as it opens, 0 → 1.
    @State private var sweep: CGFloat = 0
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
                    sweepLayer(size: size)
                    haloLayer(centre: centre)
                    particles(centre: centre)
                    orbitLayer(centre: centre)
                    ignitionLayer(centre: centre)
                    textBlock(size: size, centre: centre)
                    cancelButton(size: size)
                    dustLayer(from: from, centre: centre)
                    trailLayer(centre: centre, caret: caret)
                    starLayer(from: from, centre: centre, caret: caret)
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .opacity(overlayOpacity)
                .onAppear { start(centre: centre) }
                .onChange(of: transition.phase) { _, phase in react(to: phase) }
                .task(id: transition.phase == .waiting) { await rotatePhrases() }
                .task(id: transition.progress.map(ObjectIdentifier.init)) { await tickQuarters() }
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
            Text("Drafting in your voice")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text("“\(transition.idea)”")
                .font(.system(size: 15))
                .foregroundStyle(Palette.Scripts.transitionInk)
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
            progressLine
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .frame(width: size.width)
        // The percentage's line is below the board's three: the block moves down by half of it, so they stay where the board puts them.
        .position(x: size.width / 2, y: centre.y + 104 + 36 + (8 + Self.progressHeight) / 2)
        .opacity(texts)
        .offset(y: texts == 1 ? 0 : 8)
    }

    private static let progressHeight: CGFloat = 16

    /// "42%" under the phrase, from the moment the page starts writing; its room is kept before that, so nothing moves when it comes.
    private var progressLine: some View {
        ZStack {
            if let meter = transition.progress {
                WritingProgressLabel(meter: meter)
                    .font(CueStudioFont.hud)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("transition.progress")
            }
        }
        .frame(height: Self.progressHeight)
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
                .foregroundStyle(Palette.Scripts.transitionInk)
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

    /// The orbit round the star, once the page has started writing (with the words under it).
    private func orbitLayer(centre: CGPoint) -> some View {
        ZStack {
            if let meter = transition.progress {
                ProgressOrbit(meter: meter)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .position(centre)
        .opacity(texts)
        .animation(.easeOut(duration: 0.6), value: transition.progress != nil)
    }

    /// The star catching where it stops: a white flash that swells and goes, and a ring of light running out from it.
    private func ignitionLayer(centre: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, Palette.World.skyStarYou.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 30))
                .frame(width: 60, height: 60)
                .scaleEffect(0.4 + 1.6 * ignition)
                .opacity(ignition > 0 ? Double(1 - ignition) * 0.9 : 0)
            Circle()
                .stroke(Palette.aiTextStrong, lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .scaleEffect(1 + 7 * ignition)
                .opacity(ignition > 0 ? Double(1 - ignition) * 0.8 : 0)
        }
        .position(centre)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The idea's words coming apart into light as the star leaves: specks from along the field run, one after the other, on curves into the
    /// middle, small and bright as they arrive.
    private func dustLayer(from: CGPoint, centre: CGPoint) -> some View {
        ZStack {
            if let dustStart {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(dustStart)
                    Canvas { canvas, _ in drawDust(in: &canvas, elapsed: elapsed, from: from, centre: centre) }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static let dustCount = 34
    /// The last speck leaves this long after the first; each takes `dustFlight` to arrive (the last ones still run into the star after it
    /// has stopped, feeding its ignition).
    private static let dustSpread = 0.7
    private static let dustFlight = 1.0

    private func drawDust(in canvas: inout GraphicsContext, elapsed: TimeInterval, from: CGPoint, centre: CGPoint) {
        for index in 0..<Self.dustCount {
            let seed = Double(index)
            // Along the field, to the left of the arrow (or around the start when there is no field).
            let along = Self.unit(seed * 2.3)
            let start = CGPoint(x: from.x - 30 - along * 250, y: from.y - 6 + (Self.unit(seed * 4.7) - 0.5) * 22)
            let delay = Self.dustSpread * along
            let local = (elapsed - delay) / Self.dustFlight
            guard local > 0, local < 1 else { continue }
            let eased = local * local * (3 - 2 * local)
            let bend = CGPoint(x: (start.x + centre.x) / 2 + (Self.unit(seed * 6.1) - 0.5) * 120, y: min(start.y, centre.y) + 40)
            let u = 1 - eased
            let point = CGPoint(
                x: u * u * start.x + 2 * u * eased * bend.x + eased * eased * centre.x,
                y: u * u * start.y + 2 * u * eased * bend.y + eased * eased * centre.y
            )
            let size = 2.6 * (1 - 0.6 * eased)
            let opacity = local < 0.15 ? local / 0.15 : 1 - max(0, local - 0.75) / 0.25
            let colour = index % 4 == 0 ? Palette.World.skyStarYou : (index.isMultiple(of: 2) ? Palette.aiTextStrong : .white)
            canvas.fill(
                Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)),
                with: .color(colour.opacity(0.9 * opacity))
            )
        }
    }

    /// The comet's streak behind the star as it flies to the caret.
    private func trailLayer(centre: CGPoint, caret: CGPoint) -> some View {
        CometTrail(landed: landed, centre: centre, caret: caret)
            .stroke(
                LinearGradient(colors: [Palette.World.skyStarYou.opacity(0), Palette.World.skyStarYou], startPoint: .bottomTrailing, endPoint: .topLeading),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .shadow(color: Palette.World.skyStarYou.opacity(0.7), radius: 6)
            .opacity(reduceMotion ? 0 : starOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A soft band of light that crosses the page from top to bottom once, as the ring opens it.
    private func sweepLayer(size: CGSize) -> some View {
        LinearGradient(colors: [.clear, Palette.Scripts.transitionSweep, .clear], startPoint: .top, endPoint: .bottom)
            .frame(width: size.width, height: 220)
            .position(x: size.width / 2, y: -110 + (size.height + 220) * sweep)
            .blendMode(.plusLighter)
            .opacity(sweep > 0 && sweep < 1 ? 1 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Moving

    private func start(centre: CGPoint) {
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
        ignition = 0
        sweep = 0
        dustStart = nil
        react(to: transition.phase)
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2 * speed)) { overlayOpacity = 1 }
        } else {
            overlayOpacity = 1
        }
    }

    private func react(to phase: IdeaTransitionService.Phase) {
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
        dustStart = .now
        // The star ignites as it stops (the takeoff's haptic ends there with a tap).
        withAnimation(.easeOut(duration: 1.1 * speed).delay(IdeaTransitionService.riseDuration * 0.95 * speed)) { ignition = 1 }
        Task {
            try? await Task.sleep(for: .seconds((Self.dustSpread + Self.dustFlight + 0.05) * speed))
            dustStart = nil
        }
        withAnimation(.easeOut(duration: 0.5 * speed)) {
            cover = 0.84
            halo = 1
        }
    }

    /// The AI is writing: the words come up (0.4 s, a beat late) and Cancel fades in 0.3 s after them.
    private func wait() {
        // VoiceOver hears what is happening, then each phrase (polite), and starts on Cancel.
        AccessibilityNotification.Announcement(String(localized: "Drafting in your voice")).post()
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
            HapticPatterns.playLanding()
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
            withAnimation(.timingCurve(0.45, 0, 0.25, 1, duration: 1.4 * speed).delay(0.15 * speed)) { sweep = 1 }
            withAnimation(.timingCurve(0.3, 0.1, 0.25, 1, duration: IdeaTransitionService.landingDuration * speed).delay(0.2 * speed)) {
                landed = 1
                starScale = 0.6
            }
            try? await Task.sleep(for: .seconds((IdeaTransitionService.landingDuration + 0.2) * speed))
            // The star lands as the caret: a soft thump and two glints.
            HapticPatterns.playLanding()
            showsCaret = true
            withAnimation(.easeOut(duration: 0.2)) { starOpacity = 0 }
            try? await Task.sleep(for: .seconds(IdeaTransitionService.caretHold * speed))
            showsCaret = false
        }
    }

    /// Cancel or an error: the star falls 40 pt and fades (0.3 s), then the overlay fades (0.22 s).
    private func leave() {
        Haptics.soft()
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

    /// A light tick each time another quarter of the script is written (25, 50, 75%): the writing felt in the hand, never a buzz. The landing
    /// has its own.
    private func tickQuarters() async {
        guard let meter = transition.progress else { return }
        var quarters = Int(meter.fraction * 4)
        while !Task.isCancelled, transition.phase == .waiting || transition.phase == .rising, !meter.isFinished {
            try? await Task.sleep(for: .milliseconds(200))
            let now = min(3, Int(meter.fraction * 4))
            if now > quarters {
                quarters = now
                Haptics.apply()
            }
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
