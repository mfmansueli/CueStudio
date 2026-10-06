//
//  DesignCatalogueView.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Debug only: every token, icon, slider, tab bar state, shared component and effect of the design system, to check
/// them by eye and by screenshot (`-uiTestCatalogue` opens it at launch; Settings has a row for it).
struct DesignCatalogueView: View {
    enum Section: String, CaseIterable, Identifiable {
        case colors = "Colors", icons = "Icons", sliders = "Sliders", tabBar = "Tabbar", components = "Parts", effects = "Effects"
        case sky = "Sky", transition = "Transition", universe = "Universe", writing = "Writing"
        var id: String { rawValue }
    }

    @State private var section: Section = .colors
    @State private var speed = 140.0
    @State private var size = 2.0
    @State private var timing = 0.0
    @State private var sky = 1.0
    @State private var volume = 100.0
    @State private var ignite = 0
    @State private var comet = 0
    @State private var words = 0
    @State private var aura = false
    @State private var density: SkyDensity = .lively
    @State private var transitionRun = 0
    @State private var writtenWords = 0
    @State private var transitionReady = 0

    init(section: Section = .colors) {
        _section = State(initialValue: section)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(16)
            .accessibilityIdentifier("catalogue.sections")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch section {
                    case .colors: colors
                    case .icons: icons
                    case .sliders: sliders
                    case .tabBar: tabBar
                    case .components: components
                    case .effects: effects
                    case .sky: skyDemo
                    case .transition: transitionDemo
                    case .universe: universeDemo
                    case .writing: writingDemo
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .accessibilityIdentifier("catalogue.root")
    }

    // MARK: - Writing

    private static let sampleScript = """
    3 habits that fix my mornings. One: I drink water before my phone, because nothing good starts with a notification.

    Two: I write one sentence about what would make today a win. Three: I move. Ten squats, a walk around the block.

    Save this for tomorrow morning, and tell me which one stuck.
    """

    /// 4.1: the words arriving from light with the caret, and the pill; four more words every 0.7 s.
    private var writingDemo: some View {
        let words = Self.sampleScript.split(separator: " ", omittingEmptySubsequences: false)
        return VStack(alignment: .leading, spacing: 20) {
            ArrivingText(text: words.prefix(writtenWords).joined(separator: " "))
                .frame(minHeight: 220, alignment: .topLeading)
                .accessibilityIdentifier("catalogue.writingText")
            ScriptWritingPill(inMyVoice: true).frame(maxWidth: .infinity)
        }
        .task {
            writtenWords = 0
            while writtenWords < words.count {
                try? await Task.sleep(for: .milliseconds(700))
                writtenWords += 4
            }
        }
    }

    // MARK: - Universe

    /// 9.2: the core in its two small sizes and four colours, and the map with a few shared videos.
    private var universeDemo: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(CoreColor.allCases) { color in
                HStack(spacing: 12) {
                    UniverseCore(color: color, style: .compact)
                    UniverseCore(color: color, style: .preview)
                    Text(color.label).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
            UniverseMap(snapshot: Self.sampleUniverse)
                .frame(height: 340)
                .accessibilityIdentifier("catalogue.universeMap")
        }
    }

    /// Twenty-three shared videos across three topics and three platforms, as in the board.
    private static var sampleUniverse: UniverseSnapshot {
        let topics: [OnboardingTopic] = [.niche(.lifestyle), .niche(.finance), .niche(.food)]
        let platforms: [Platform] = [.tiktok, .reels, .shorts]
        let videos = (0..<23).map { index in
            UniverseVideo(date: .now.addingTimeInterval(Double(index) * 60), platform: platforms[index % 3], topic: topics[index % 3].id)
        }
        return UniverseSnapshot(videos: videos, year: Calendar.current.component(.year, from: .now), topics: topics)
    }

    // MARK: - Transition

    /// The idea's star over a stand-in for Scripts, held in "waiting" until "Ready" (so it can be looked at); "Again" starts it over.
    private var transitionDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The star that is the transition from an idea to its script. It waits for the AI until you press Ready.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
            HStack(spacing: 10) {
                Button("Again") { transitionRun += 1 }.buttonStyle(.cueSecondary(.compact, expands: false)).accessibilityIdentifier("catalogue.transitionAgain")
                Button("Ready") { transitionReady += 1 }.buttonStyle(.cuePrimary(.compact, expands: false)).accessibilityIdentifier("catalogue.transitionReady")
            }
            TransitionDemo(run: transitionRun, ready: transitionReady)
                .id(transitionRun)
                .frame(height: 560)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    // MARK: - Colors

    private var colors: some View {
        let swatches: [(String, Color)] = [
            ("bg", Palette.bg), ("surface", Palette.surface), ("surface2", Palette.surface2), ("surface3", Palette.surface3),
            ("acc", Palette.acc), ("aiText", Palette.aiText), ("record", Palette.record), ("success", Palette.success),
            ("info", Palette.info), ("warn", Palette.warn), ("danger", Palette.danger), ("ink", Palette.ink),
            ("ink2", Palette.ink2), ("inkHint", Palette.inkHint), ("ink3", Palette.ink3), ("separator", Palette.separator),
            ("warm", Palette.World.warm), ("mint", Palette.World.mint), ("pink", Palette.World.pink), ("sky", Palette.World.sky),
            ("TikTok", Palette.Platform.tikTok), ("Reels", Palette.Platform.reels), ("Shorts", Palette.Platform.shorts),
            ("YouTube", Palette.Platform.youTube), ("LinkedIn", Palette.Platform.linkedIn), ("Stories", Palette.Platform.stories),
            ("recPillRing", Palette.Camera.recPillRing),
            ("Slider.track", Palette.Slider.track), ("Slider.fill", Palette.Slider.fill), ("Slider.thumb", Palette.Slider.thumb),
            ("selectionBar", Palette.Page.selectionBar), ("aiReplacedFill", Palette.Page.aiReplacedFill), ("stripFill", Palette.Page.stripFill),
            ("stateReady", Palette.Page.stateReadyFill), ("stateDraft", Palette.Page.stateDraftFill), ("adTag", Palette.Scripts.adTagFill),
            ("emptyRing", Palette.Scripts.emptyRing), ("emptyOrbiter", Palette.Scripts.emptyOrbiter), ("skyStarYou", Palette.World.skyStarYou),
        ]
        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color).frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
                        Text(name).font(.caption2).foregroundStyle(Palette.ink2).lineLimit(1)
                    }
                }
            }
            heading("bgWash")
            BgWash()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
    }

    // MARK: - Icons

    private var icons: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Stroke ≈ 1.6 pt at every size")
            HStack(alignment: .bottom, spacing: 18) {
                ForEach([12.0, 16, 20, 22, 26, 30, 44], id: \.self) { size in
                    VStack(spacing: 4) {
                        CueIconView(.editCut, size: size).foregroundStyle(Palette.ink)
                        Text("\(Int(size))").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.inkHint)
                    }
                }
            }
            heading("Filled: play · Takes · marked best take")
            HStack(spacing: 24) {
                CueIconView(.play, size: 26).foregroundStyle(Palette.ink)
                CueIconView(.takes, size: 26).foregroundStyle(Palette.ink)
                CueIconView(.bestTake, size: 26).foregroundStyle(Palette.ink)
                CueIconView(.bestTake, size: 26, isFilled: true).foregroundStyle(Palette.acc)
                RecordGlyph().foregroundStyle(Palette.ink2)
            }
            iconGrid
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(CueIcon.allCases, id: \.rawValue) { icon in
                VStack(spacing: 6) {
                    CueIconView(icon, size: 26).foregroundStyle(color(of: icon))
                    Text(String(describing: icon)).font(.system(size: 9)).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func color(of icon: CueIcon) -> Color {
        switch icon {
        case .sparkAi, .smartEdit, .hooks, .needAnIdea: Palette.aiText
        case .record: Palette.record
        case .bestTake, .favorite: Palette.acc
        default: Palette.ink
        }
    }

    // MARK: - Sliders

    private var sliders: some View {
        VStack(alignment: .leading, spacing: 26) {
            heading("Min · default · max")
            CueSlider(
                value: .constant(80), range: CueSliderSpec.speed.range, step: CueSliderSpec.speed.step,
                defaultValue: CueSliderSpec.speed.defaultValue, label: "Speed", valueText: "80 wpm", systemIcon: .speed,
                minCaption: "80 wpm", maxCaption: "220 wpm", accessibilityIdentifier: "catalogue.slider.min"
            )
            CueSlider(
                value: .constant(150), range: CueSliderSpec.speed.range, step: CueSliderSpec.speed.step,
                defaultValue: CueSliderSpec.speed.defaultValue, label: "Speed", valueText: "150 wpm", systemIcon: .speed,
                minCaption: "80 wpm", maxCaption: "220 wpm", accessibilityIdentifier: "catalogue.slider.default"
            )
            CueSlider(
                value: .constant(220), range: CueSliderSpec.speed.range, step: CueSliderSpec.speed.step,
                defaultValue: CueSliderSpec.speed.defaultValue, label: "Speed", valueText: "220 wpm", systemIcon: .speed,
                minCaption: "80 wpm", maxCaption: "220 wpm", accessibilityIdentifier: "catalogue.slider.max"
            )
            heading("Continuous · default detent")
            CueSlider(
                value: $speed, range: 80...220, defaultValue: 150, label: "Speed", valueText: "\(Int(speed)) wpm",
                spokenValue: "\(Int(speed)) words per minute", systemIcon: .speed, minCaption: "80 wpm", maxCaption: "220 wpm",
                allowsTyping: true, accessibilityIdentifier: "catalogue.slider.speed"
            )
            heading("Stepped")
            CueSlider(
                value: $size, range: 0...3, step: 1, defaultValue: 2, label: "Text size", valueText: ["S", "M", "L", "XL"][Int(size)],
                systemIcon: .textSize, accessibilityIdentifier: "catalogue.slider.size"
            )
            heading("From center")
            CueSlider(
                value: $timing, range: -300...300, defaultValue: 0, origin: .center, label: "Caption timing",
                valueText: "\(Int(timing)) ms", systemIcon: .captions, minCaption: "Earlier", maxCaption: "Later"
            )
            heading("In a row")
            CueSlider(
                value: $sky, range: 0...2, step: 1, style: .row, label: "Sky", valueText: SkyDensity.allCases[Int(sky)].label
            )
            heading("On camera")
            CueSlider(value: $volume, range: 0...200, defaultValue: 100, style: .compact, label: "Voice", valueText: "\(Int(volume))%")
                .padding(10)
                .background(LinearGradient(colors: [.orange, .purple], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 16))
            heading("Disabled")
            CueSlider(value: $volume, range: 0...200, label: "Music", valueText: "\(Int(volume))%").disabled(true)
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("The system tab bar's icons (the bar itself is native: see any tab)")
            HStack(spacing: 24) {
                ForEach([CueIcon.scripts, .takes, .profile, .settings], id: \.self) { icon in
                    Image(uiImage: CueTabImage.template(icon)).foregroundStyle(Palette.accText)
                }
                Image(uiImage: CueTabImage.record)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Components

    private var components: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("ThemeRail · row 3 × 30 · chip 3 × 14")
            HStack(spacing: 14) {
                ForEach([Palette.World.warm, Palette.World.mint, Palette.World.pink, Palette.World.sky], id: \.self) { ThemeRail(color: $0) }
                ForEach([Palette.World.warm, Palette.World.mint, Palette.World.pink], id: \.self) { ThemeRail(color: $0, size: .chip) }
            }
            heading("PlatformDot · 7 · 6")
            HStack(spacing: 14) {
                PlatformDot(color: Palette.Platform.tikTok)
                PlatformDot(color: Palette.Platform.reels)
                PlatformDot(color: Palette.Platform.shorts, isSmall: true)
                PlatformDot(color: Palette.Platform.youTube, isSmall: true)
            }
            heading("RecPill · 26 to see · 44 to touch")
            RecPill {}
            heading("StateChip")
            HStack(spacing: 8) {
                ForEach(StateChip.Kind.allCases, id: \.self) { StateChip(kind: $0) }
            }
            heading("EmptyState")
            EmptyState(
                title: "No takes yet", message: "Record one and it shows up here.", actionTitle: "Record a take", action: {},
                linkTitle: "Write a script first", link: {}, accessibilityPrefix: "catalogue.emptyState"
            )
            .padding(.vertical, 12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        }
    }

    // MARK: - Effects

    private var effects: some View {
        VStack(alignment: .leading, spacing: 26) {
            heading("Horizon")
            HorizonLine().frame(height: 24)
            heading("Ignite (tap)")
            IgniteEffect(trigger: ignite).frame(width: 120, height: 120).frame(maxWidth: .infinity)
                .contentShape(Rectangle()).onTapGesture { ignite += 1; Haptics.success() }
                .accessibilityIdentifier("catalogue.ignite")
            heading("Comet (tap)")
            CometPlayer(path: Self.route, trigger: comet).frame(height: 140)
                .contentShape(Rectangle()).onTapGesture { comet += 1 }
            heading("Words from light (tap)")
            WordsFromLight(text: "Okay, real talk. Three tiny habits completely changed my mornings.", trigger: words)
                .contentShape(Rectangle()).onTapGesture { words += 1 }
            heading("AI aura (tap)")
            Text("✦ Writing in your voice").foregroundStyle(Palette.aiText).frame(maxWidth: .infinity, minHeight: 80)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                .aiAura(isActive: aura).onTapGesture { aura.toggle() }
            heading("Shine sweep")
            Text("Get started").font(.headline).foregroundStyle(Palette.accInk).frame(maxWidth: .infinity, minHeight: 54)
                .background(Palette.acc, in: Capsule()).shineSweep(interval: 3)
        }
    }

    private static var route: Path {
        var path = Path()
        path.move(to: CGPoint(x: 20, y: 120))
        path.addCurve(to: CGPoint(x: 320, y: 20), control1: CGPoint(x: 120, y: 130), control2: CGPoint(x: 220, y: 20))
        return path
    }

    // MARK: - Sky

    private var skyDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Density", selection: $density) {
                ForEach(SkyDensity.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            StarfieldView(density: density)
                .frame(height: 520)
                .background(Palette.bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(CueStudioFont.hud).textCase(.uppercase).foregroundStyle(Palette.accText)
    }
}

/// The transition over a mock Scripts (the dock at the bottom), in a box.
private struct TransitionDemo: View {
    let run: Int
    let ready: Int

    @State private var transition = IdeaTransitionService()

    var body: some View {
        ZStack {
            Palette.bg
            VStack(alignment: .leading, spacing: 10) {
                Text("Scripts").font(.largeTitle.bold()).foregroundStyle(Palette.ink)
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface).frame(height: 64)
                }
                Spacer()
                Text("3 things I stopped buying this year").padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .dockSurface().foregroundStyle(Palette.ink)
            }
            .padding(16)
            .scaleEffect(dims ? 0.94 : 1, anchor: UnitPoint(x: 0.5, y: 0.4))
            .brightness(dims ? -0.4 : 0)
            .saturation(dims ? 0.7 : 1)
            .blur(radius: dims ? 10 : 0)
            .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: IdeaTransitionService.riseDuration), value: dims)
            StarTransitionOverlay(transition: transition)
        }
        .onAppear {
            transition.begin(
                from: CGPoint(x: 330, y: 560), idea: "3 things I stopped buying this year", platformName: "TikTok", abort: {}, arrive: {}
            )
        }
        .onChange(of: ready) { Task { await transition.contentReady() } }
    }

    private var dims: Bool { transition.phase == .rising || transition.phase == .waiting }
}

#Preview {
    DesignCatalogueView()
}
#endif
