//
//  StarTransitionOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Draws the star that is the transition from an idea to its script (`IdeaTransitionService`, 09 §8, `motion/README.md`), over the whole
/// app: the star is born on the arrow (a spring and a bloom of light with a ring running out of it, 0.12 s) and rises along a curve to the
/// middle (34% of the height, 1.2 s, `(0.2, 0.8, 0.2, 1)`), drawing a streak of light behind it while it is fast, while the screen behind
/// darkens (84%); a halo breathes around it and twelve specks gather toward it; "Drafting in your voice", the idea, a phrase that changes
/// every 1.6 s and how much of the script is written ("42%", an estimate: `WritingProgressEstimate`) sit under it, with Cancel at the bottom.
/// When the script is ready the cover goes solid (0.3 s), the ring opens (0.8 s), the star lands as the caret (0.9 s) and the page writes.
/// Cancel or an error: the star falls 40 pt (0.3 s), the overlay fades (0.22 s).
///
/// Layered over the board's sequence: as the star leaves, the idea's words come apart into a stream of light that runs into it (`dust`);
/// it ignites where it stops (a flash and a ring of light, with the end of the takeoff's haptic); an orbit round it closes as the script
/// is written (`ProgressOrbit`), with a light tick at each quarter; flying to the caret it leaves a comet's streak (`CometTrail`), lands
/// with its haptic, and a light crosses the page once. Slower than the board's (the owner's calls, 20/10 and 25/10/2026: the effects should
/// be seen; the script is written behind them all the while).
///
/// What moves here is cheap to draw: glows are gradients, not shadows, and the cover's ring is a shape with a hole, not a mask, so no
/// picture is drawn off screen each frame; the app behind is a still (`TransitionBackdrop`).
///
/// An Ultra AI script (owner's call, 29/10/2026) keeps the sequence in Cue's violet and gold: the star is a ✦ (`SparkShape`) in a violet glow,
/// its streaks are violet, the specks are small ✦, the ignition's ring is gold; the orbit is one arc per Ultra AI pass (`UltraPassOrbit`), the
/// phrase says which pass it is ("Checking the facts"), with a light tick as each ends, and at the finish the passes' nodes run into the star.
/// Larger than Apple Intelligence's (the owner's call, 30/10/2026: a paid script waits in something more alive): a larger ✦ that pulses with
/// each step of the words, inside a scene of its own (`UltraWaitScene`: a small turning galaxy, a moon for each pass done, shooting stars, comets in a
/// long wait), with the ring of passes round it at a third of the screen's width and the words under the scene. Its finish is longer
/// (`IdeaTransitionService.ultraFinishDuration`): everything spirals into the star, it flashes, and then the ring opens. After 45 s the phrase
/// says it is taking a little longer.
///
/// Reduce Motion (09 §7): no rise or ring, no stream, bloom, streaks, flash or light. The overlay fades in (0.2 s) with the text and Cancel in
/// place, then crossfades into the page (0.3 s). The timings are the board's in every situation (`IdeaTransitionService.speed` is 1; only UI tests shorten it).
struct StarTransitionOverlay: View {
    let transition: IdeaTransitionService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Everything that moves is a value that is animated to its place.
    @State private var path: CGFloat = 0
    /// Where the star was a beat ago on its flight: the end of its streak (`RiseTrail`).
    @State private var tailPath: CGFloat = 0
    @State private var starScale: CGFloat = 0.7
    /// The star being born on the arrow, 0 → 1 (with a spring's overshoot).
    @State private var born: CGFloat = 0
    /// The bloom of light and its ring at the arrow as the star is born, 0 → 1.
    @State private var launch: CGFloat = 0
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
    /// This transition's phrases, made once (each is a localized string).
    @State private var phrases: [String] = []
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
    /// An Ultra AI script there: its passes' nodes run into the star, 0 → 1.
    @State private var gather: CGFloat = 0
    /// Ultra AI's scene: when it began (the star ignited) and when its finish began, in its clock (`UltraWaitScene.now`).
    @State private var sceneBegan: TimeInterval = 0
    @State private var sceneFinish: TimeInterval?
    /// The Ultra AI pass the phrase says, a step behind the meter so the phrase changes in its own movement.
    @State private var shownPass = 0
    /// The star this overlay was started for (`IdeaTransitionService.run`): a star sent while the last one still finishes starts afresh.
    @State private var startedRun = 0
    /// VoiceOver goes to Cancel first (09 §A).
    @AccessibilityFocusState private var cancelHasFocus: Bool

    private var speed: Double { transition.speed }
    private var isUltra: Bool { transition.engine == .ultra }
    /// The star's colour: the sky's own star, or Ultra AI's violet.
    private var starGlow: Color { isUltra ? Palette.Scripts.ultraStarGlow : Palette.World.skyStarYou }

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
                let control = CGPoint(x: (from.x + centre.x) / 2 + 40, y: min(from.y, centre.y) - 60)
                let reach = UltraWaitScene.radius(in: size)
                ZStack(alignment: .topLeading) {
                    coverLayer(centre: centre)
                    sweepLayer(size: size)
                    haloLayer(centre: centre, reach: reach)
                    if isUltra {
                        ultraScene(.back, centre: centre, reach: reach)
                    } else {
                        particles(centre: centre)
                    }
                    orbitLayer(centre: centre, reach: reach)
                    ignitionLayer(centre: centre, reach: reach)
                    textBlock(size: size, centre: centre, reach: reach)
                    cancelButton(size: size)
                    dustLayer(from: from, centre: centre)
                    launchLayer(from: from)
                    riseTrailLayer(from: from, control: control, centre: centre, size: size)
                    trailLayer(centre: centre, caret: caret)
                    starLayer(from: from, control: control, centre: centre, caret: caret)
                    if isUltra { ultraScene(.front, centre: centre, reach: reach) }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .opacity(overlayOpacity)
                .onAppear { start(centre: centre) }
                .onChange(of: transition.run) { start(centre: centre) }
                .onChange(of: transition.phase) { _, phase in react(to: phase) }
                .task(id: transition.phase == .waiting) { await rotatePhrases() }
                .task(id: transition.progress.map(ObjectIdentifier.init)) { await tickQuarters() }
                .onChange(of: transition.progress?.pass?.index) { _, index in movePass(to: index) }
            }
        }
        .allowsHitTesting(transition.isActive)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Layers

    /// The dark cover. While the ring opens, the cover has a hole growing from the star, so the page shows through it.
    private func coverLayer(centre: CGPoint) -> some View {
        RingCover(ring: ring, centre: centre)
            .fill(Palette.Scripts.transitionCover, style: FillStyle(eoFill: true))
            .opacity(cover)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func haloLayer(centre: CGPoint, reach: CGFloat) -> some View {
        // Ultra AI's spreads over its whole scene.
        let width = isUltra ? reach * 2.4 : 170
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            // `cstHalo`: scale .92 ↔ 1.08 and opacity .55 ↔ .9, in a 2.6 s breath.
            let phase = reduceMotion ? 0.5 : 0.5 - 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.6)
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.Scripts.transitionHalo, Palette.Scripts.transitionHalo.opacity(0.24), .clear],
                    center: .center, startRadius: 0, endRadius: width / 2
                ))
                .frame(width: width, height: width)
                .scaleEffect(0.92 + 0.16 * phase)
                .opacity(halo * (0.55 + 0.35 * phase))
                .position(centre)
        }
        .accessibilityHidden(true)
    }

    /// Twelve specks gathering toward the star: each starts 64–134 pt away (in the upper half of the circle) and shrinks into it.
    private func particles(centre: CGPoint) -> some View {
        let ultra = isUltra
        // At the display's own rate: at 30 fps the fastest specks stepped 5 pt at a time on a 120 Hz screen.
        return TimelineView(.animation(paused: reduceMotion)) { context in
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
                    let colour = index % 3 == 0 ? Palette.World.skyStarYou : (ultra && index % 3 == 1 ? Palette.aiText : Palette.aiTextStrong)
                    // Ultra AI's are small ✦, turning as they gather.
                    let speck = ultra
                        ? SparkShape.path(center: point, radius: size * 1.4, turn: .degrees(90 * pull))
                        : Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
                    canvas.fill(speck, with: .color(colour.opacity(opacity)))
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

    private func textBlock(size: CGSize, centre: CGPoint, reach: CGFloat) -> some View {
        let words = VStack(spacing: 8) {
            Text(transition.engine == .ultra ? "Drafting with Ultra AI" : "Drafting in your voice")
                .cueFont(20, weight: .bold)
                .tracking(-0.2)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text("“\(transition.idea)”")
                .cueFont(15)
                .foregroundStyle(Palette.Scripts.transitionInk)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 300)
            Text(currentPhrase)
                .cueFont(16, weight: .medium)
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
        return Group {
            if isUltra {
                // Under Ultra AI's scene, from its top: a larger type grows down, never into the ring.
                words
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .offset(y: centre.y + reach * UltraWaitScene.ringShare + UltraWaitScene.wordsGap)
            } else {
                // The percentage's line is below the board's three: the block moves down by half of it, so they stay where the board puts them.
                words.position(x: size.width / 2, y: centre.y + 104 + 36 + (8 + Self.progressHeight) / 2)
            }
        }
        .opacity(texts)
        .offset(y: texts == 1 ? 0 : 8)
    }

    private static let progressHeight: CGFloat = 16

    /// What Ultra AI is doing in pass `index` of `count`: the draft, the claims checked (three passes only), the polish in the creator's voice.
    private static func passPhrase(_ index: Int, of count: Int) -> String {
        if index == 0 { return String(localized: "Writing the draft") }
        if index < count - 1 { return String(localized: "Checking the facts") }
        return String(localized: "Polishing in your voice")
    }

    /// "42%" under the phrase, from the moment the page starts writing; its room is kept before that, so nothing moves when it comes.
    private var progressLine: some View {
        ZStack {
            if let meter = transition.progress {
                WritingProgressLabel(meter: meter)
                    .hudFont()
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("transition.progress")
            }
        }
        .frame(height: Self.progressHeight)
    }

    private var currentPhrase: String {
        if finishShown { return IdeaTransitionService.finishPhrase }
        if isTakingLong { return IdeaTransitionService.longWaitPhrase }
        if isUltra { return Self.passPhrase(shownPass, of: transition.progress?.pass?.count ?? UltraFlow.checked.calls) }
        guard !phrases.isEmpty else { return "" }
        return phrases[phraseIndex % phrases.count]
    }

    private func cancelButton(size: CGSize) -> some View {
        Button { transition.cancel() } label: {
            Text("Cancel")
                .cueFont(15, weight: .semibold)
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

    /// The star: born on the arrow, it rises along a curve to the middle, breathes while the AI writes, grows at the finish and flies to the
    /// caret. Its glow is a gradient (two shadows were two pictures drawn off screen each frame).
    private func starLayer(from: CGPoint, control: CGPoint, centre: CGPoint, caret: CGPoint) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || transition.phase != .waiting)) { context in
            // `cstBreath`: 1.4 ↔ 1.65 in 1.6 s while it waits.
            let breath = transition.phase == .waiting && !reduceMotion
                ? 1.4 + 0.25 * (0.5 - 0.5 * cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.6)) : starScale
            // Ultra AI's swells a little with each step of its words.
            let pulse = isUltra && !reduceMotion && transition.phase == .waiting ? UltraWaitScene.pulse(transition.progress, at: UltraWaitScene.now) : 0
            let glow: CGFloat = isUltra ? 58 : 38
            ZStack {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [starGlow.opacity(0.85), starGlow.opacity(0.28), .clear],
                            center: .center, startRadius: 2, endRadius: glow / 2
                        ))
                        .frame(width: glow, height: glow)
                        .scaleEffect(1 + 0.35 * pulse)
                    if isUltra {
                        // Ultra AI's ✦: white, warming to the sky star's gold at its foot.
                        SparkShape()
                            .fill(LinearGradient(colors: [.white, .white, Palette.World.skyStarYou], startPoint: .top, endPoint: .bottom))
                            .frame(width: 22, height: 22)
                            .scaleEffect(1 + 0.18 * pulse)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                    }
                }
                // Two effects, so the birth's spring and the flight's growth each keep their own animation.
                .scaleEffect(born)
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

    /// The star being born on the arrow: a bloom of white and violet light that swells and goes, and a thin ring running out of it.
    private func launchLayer(from: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.95), Palette.aiTextStrong.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 26
                ))
                .frame(width: 52, height: 52)
                .modifier(LightBurst(progress: launch, from: 0.3, to: 1.8, peak: 1))
            // Drawn at its widest and grown into it, so its line stays thin (a small ring scaled up thickened with it).
            Circle()
                .strokeBorder(Palette.World.skyStarYou, lineWidth: 1.5)
                .frame(width: 92, height: 92)
                .modifier(LightBurst(progress: launch, from: 0.18, to: 1, peak: 0.8))
        }
        .position(from)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The streak behind the rising star: a soft wide stroke and a bright thin one, fading toward the arrow.
    private func riseTrailLayer(from: CGPoint, control: CGPoint, centre: CGPoint, size: CGSize) -> some View {
        let start = UnitPoint(x: from.x / max(size.width, 1), y: from.y / max(size.height, 1))
        let end = UnitPoint(x: centre.x / max(size.width, 1), y: centre.y / max(size.height, 1))
        let trail = RiseTrail(head: path, tail: tailPath, from: from, control: control, centre: centre)
        return ZStack {
            trail.stroke(
                LinearGradient(colors: [starGlow.opacity(0), starGlow.opacity(0.4)], startPoint: start, endPoint: end),
                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
            )
            trail.stroke(
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.9)], startPoint: start, endPoint: end),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .opacity(reduceMotion ? 0 : starOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The orbit round the star, once the page has started writing (with the words under it); Ultra AI's in its passes, whose nodes stay
    /// as the words go at the finish, to run into the star.
    private func orbitLayer(centre: CGPoint, reach: CGFloat) -> some View {
        ZStack {
            if let meter = transition.progress {
                Group {
                    if isUltra {
                        UltraPassOrbit(meter: meter, gathered: gather, diameter: reach * 2 * UltraWaitScene.ringShare)
                    } else {
                        ProgressOrbit(meter: meter)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .position(centre)
        .opacity(isUltra && transition.phase == .revealing ? 1 : texts)
        .animation(.easeOut(duration: 0.6), value: transition.progress != nil)
    }

    /// Ultra AI's scene round the star (`UltraWaitScene`), in its two layers: it comes up with the words, and stays for its finish.
    private func ultraScene(_ layer: UltraWaitScene.Layer, centre: CGPoint, reach: CGFloat) -> some View {
        UltraWaitScene(layer: layer, meter: transition.progress, centre: centre, radius: reach, began: sceneBegan, finish: sceneFinish)
            .opacity(transition.phase == .revealing ? 1 : texts)
    }

    /// The star catching where it stops: a white flash that swells and goes, and a ring of light running out from it.
    private func ignitionLayer(centre: CGPoint, reach: CGFloat) -> some View {
        // Ultra AI's ring of light runs out past its ring of passes.
        let ring = isUltra ? reach * 2 * UltraWaitScene.ringShare * 1.25 : 160
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, starGlow.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 30))
                .frame(width: 60, height: 60)
                .modifier(LightBurst(progress: ignition, from: 0.4, to: 2, peak: 0.9))
            Circle()
                .strokeBorder(isUltra ? Palette.World.skyStarYou : Palette.aiTextStrong, lineWidth: 1.5)
                .frame(width: ring, height: ring)
                .modifier(LightBurst(progress: ignition, from: 20 / ring, to: 1, peak: 0.8))
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

    /// How far behind the star its streak ends, in time.
    private static let trailLag = 0.08

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
        let trail = CometTrail(landed: landed, centre: centre, caret: caret)
        let colours = [starGlow.opacity(0), starGlow]
        // Its glow is a wider, fainter stroke under it, not a shadow.
        return ZStack {
            trail.stroke(
                LinearGradient(colors: colours, startPoint: .bottomTrailing, endPoint: .topLeading),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .opacity(0.3)
            trail.stroke(
                LinearGradient(colors: colours, startPoint: .bottomTrailing, endPoint: .topLeading),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
        .opacity(reduceMotion ? 0 : starOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A soft band of light that crosses the page from top to bottom once, as the ring opens it.
    private func sweepLayer(size: CGSize) -> some View {
        LinearGradient(colors: [.clear, Palette.Scripts.transitionSweep, .clear], startPoint: .top, endPoint: .bottom)
            .frame(width: size.width, height: 220)
            // Off the screen at rest, above it before and below it after: nothing to hide. A plain blend: at 12% over the dark page it
            // lights what it crosses as much as an additive one, without a filter to composite each frame.
            .position(x: size.width / 2, y: -110 + (size.height + 220) * sweep)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Moving

    private func start(centre: CGPoint) {
        guard startedRun != transition.run else { return }
        startedRun = transition.run
        path = 0
        tailPath = 0
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
        born = reduceMotion ? 1 : 0
        launch = 0
        phrases = IdeaTransitionService.phrases(platform: transition.platformName)
        ignition = 0
        sweep = 0
        gather = 0
        shownPass = 0
        sceneBegan = UltraWaitScene.now + IdeaTransitionService.ignitionTime * speed
        sceneFinish = nil
        dustStart = nil
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2 * speed)) { overlayOpacity = 1 }
        } else {
            overlayOpacity = 1
        }
        // The animations start on the next frame: this one also builds the page opened under the star (on the first send after a launch,
        // much else for the first time too), and an animation started in it came out of it a third of a second along (26/10/2026).
        Task { @MainActor in react(to: transition.phase) }
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

    /// The star is born on the arrow (a spring, a bloom and its ring) and, a beat later, rises to the middle (1.2 s) while the screen
    /// darkens to 84% behind it (0.5 s); the halo comes up with it.
    private func rise() {
        if reduceMotion {
            path = 1
            tailPath = 1
            starScale = 1.4
            withAnimation(.easeOut(duration: 0.2 * speed)) {
                cover = 0.84
                halo = 1
                texts = 1
                cancelOpacity = 1
            }
            return
        }
        withAnimation(.spring(duration: 0.32 * speed, bounce: 0.45)) { born = 1 }
        withAnimation(.easeOut(duration: 0.45 * speed)) { launch = 1 }
        let flight = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: IdeaTransitionService.flightDuration * speed)
        withAnimation(flight.delay(IdeaTransitionService.launchDelay * speed)) {
            path = 1
            starScale = 1.4
        }
        withAnimation(flight.delay((IdeaTransitionService.launchDelay + Self.trailLag) * speed)) { tailPath = 1 }
        dustStart = .now
        // The star ignites as it stops (the takeoff's haptic ends there with a tap).
        withAnimation(.easeOut(duration: 1.1 * speed).delay(IdeaTransitionService.ignitionTime * speed)) { ignition = 1 }
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
        AccessibilityNotification.Announcement(
            transition.engine == .ultra ? String(localized: "Drafting with Ultra AI") : String(localized: "Drafting in your voice")
        ).post()
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
        let lead = transition.coverTime
        if isUltra {
            // Ultra AI's moons and dust spiral into the star (`UltraWaitScene`) with its passes' nodes, a swelling hum under them; the star
            // swells as they reach it, and flashes.
            sceneFinish = UltraWaitScene.now
            if !reduceMotion { HapticPatterns.playUltraFinish() }
            let flash = IdeaTransitionService.ultraFlashTime
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.5, 0, 0.7, 1, duration: flash * speed)) { gather = 1 }
            withAnimation(.easeOut(duration: 0.3 * speed)) {
                texts = 0
                cancelOpacity = 0
            }
            withAnimation(.easeOut(duration: lead * speed)) { cover = 1 }
            withAnimation(.spring(duration: 0.4 * speed, bounce: 0.3).delay((flash - 0.15) * speed)) { starScale = reduceMotion ? 1.4 : 2.6 }
        } else {
            withAnimation(.easeOut(duration: lead * speed)) {
                texts = 0
                cancelOpacity = 0
                cover = 1
                starScale = reduceMotion ? 1.4 : 2.6
            }
        }
        if reduceMotion {
            HapticPatterns.playLanding()
            // A 0.3 s crossfade into the page, no ring: the cover simply goes.
            withAnimation(.easeOut(duration: 0.3 * speed).delay(lead * speed)) {
                cover = 0
                halo = 0
                starOpacity = 0
            }
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(lead * speed))
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
        // Ultra AI's tick as each pass ends (`movePass`).
        guard let meter = transition.progress, !isUltra else { return }
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
        // Ultra AI's phrase says its pass (`movePass`), until a long wait says so.
        if isUltra {
            try? await Task.sleep(for: .seconds(IdeaTransitionService.ultraLongWait * speed))
            guard !Task.isCancelled, transition.phase == .waiting else { return }
            withAnimation(.easeOut(duration: 0.3 * speed)) { phraseShown = false }
            try? await Task.sleep(for: .seconds(0.3 * speed))
            guard !Task.isCancelled, transition.phase == .waiting else { return }
            isTakingLong = true
            withAnimation(.easeOut(duration: 0.3 * speed)) { phraseShown = true }
            AccessibilityNotification.Announcement(currentPhrase).post()
            return
        }
        let count = phrases.count
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

    /// Ultra AI has started another pass: the node of the one that ended lights (`UltraPassOrbit`) with a light tick, and the phrase goes
    /// up and out for the new pass's.
    private func movePass(to index: Int?) {
        guard isUltra, let index, index > shownPass, transition.phase == .waiting || transition.phase == .rising else { return }
        Haptics.apply()
        Task {
            withAnimation(.easeOut(duration: 0.3 * speed)) { phraseShown = false }
            try? await Task.sleep(for: .seconds(0.3 * speed))
            guard !finishShown else { return }
            shownPass = index
            withAnimation(.easeOut(duration: 0.3 * speed)) { phraseShown = true }
            AccessibilityNotification.Announcement(currentPhrase).post()
        }
    }
}
