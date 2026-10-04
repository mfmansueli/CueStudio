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
        case colors = "Colors", icons = "Icons", sliders = "Sliders", tabBar = "Tabbar", components = "Parts", effects = "Effects", sky = "Sky"
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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .accessibilityIdentifier("catalogue.root")
    }

    // MARK: - Colors

    private var colors: some View {
        let swatches: [(String, Color)] = [
            ("bg", Palette.bg), ("surface", Palette.surface), ("surface2", Palette.surface2), ("surface3", Palette.surface3),
            ("acc", Palette.acc), ("aiText", Palette.aiText), ("record", Palette.record), ("success", Palette.success),
            ("info", Palette.info), ("warn", Palette.warn), ("danger", Palette.danger), ("ink", Palette.ink),
            ("ink2", Palette.ink2), ("inkHint", Palette.inkHint), ("ink3", Palette.ink3), ("separator", Palette.separator),
            ("warm", Palette.worldWarm), ("mint", Palette.worldMint), ("pink", Palette.worldPink), ("sky", Palette.worldSky),
            ("TikTok", Palette.platformTikTok), ("Reels", Palette.platformReels), ("Shorts", Palette.platformShorts),
            ("YouTube", Palette.platformYouTube), ("LinkedIn", Palette.platformLinkedIn), ("Stories", Palette.platformStories),
            ("recPillRing", Palette.recPillRing),
            ("sliderTrack", Palette.sliderTrack), ("sliderFill", Palette.sliderFill), ("sliderThumb", Palette.sliderThumb),
            ("selectionBar", Palette.selectionBar), ("aiReplacedFill", Palette.aiReplacedFill), ("stripFill", Palette.stripFill),
            ("stateReady", Palette.stateReadyFill), ("stateDraft", Palette.stateDraftFill), ("adTag", Palette.adTagFill),
            ("emptyRing", Palette.emptyRing), ("emptyOrbiter", Palette.emptyOrbiter), ("skyStarYou", Palette.skyStarYou),
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
                ForEach([Palette.worldWarm, Palette.worldMint, Palette.worldPink, Palette.worldSky], id: \.self) { ThemeRail(color: $0) }
                ForEach([Palette.worldWarm, Palette.worldMint, Palette.worldPink], id: \.self) { ThemeRail(color: $0, size: .chip) }
            }
            heading("PlatformDot · 7 · 6")
            HStack(spacing: 14) {
                PlatformDot(color: Palette.platformTikTok)
                PlatformDot(color: Palette.platformReels)
                PlatformDot(color: Palette.platformShorts, isSmall: true)
                PlatformDot(color: Palette.platformYouTube, isSmall: true)
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

#Preview {
    DesignCatalogueView()
}
#endif
