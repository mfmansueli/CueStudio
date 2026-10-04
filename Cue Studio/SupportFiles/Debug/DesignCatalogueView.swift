//
//  DesignCatalogueView.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Debug only: every token, icon, orb variant and effect of the v27 design system on one screen, to check
/// them by eye and by screenshot (`-uiTestCatalogue` opens it at launch; Settings has a row for it).
struct DesignCatalogueView: View {
    enum Section: String, CaseIterable, Identifiable {
        case colors = "Colors", icons = "Icons", orbs = "Orbs", effects = "Effects", sky = "Sky"
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
                    case .orbs: orbs
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
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(swatches, id: \.0) { name, color in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color).frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
                    Text(name).font(.caption2).foregroundStyle(Palette.ink2).lineLimit(1)
                }
            }
        }
    }

    // MARK: - Icons

    private var icons: some View {
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

    // MARK: - Orbs

    private var orbs: some View {
        VStack(alignment: .leading, spacing: 26) {
            heading("Continuous · default detent")
            OrbSlider(
                value: $speed, range: 80...220, defaultValue: 150, label: "Speed", valueText: "\(Int(speed)) wpm",
                spokenValue: "\(Int(speed)) words per minute", systemIcon: .speed, minCaption: "Slow", maxCaption: "Fast",
                allowsTyping: true, accessibilityIdentifier: "catalogue.orb.speed"
            )
            heading("Stepped")
            OrbSlider(
                value: $size, range: 0...3, step: 1, defaultValue: 1, label: "Text size", valueText: ["S", "M", "L", "XL"][Int(size)],
                systemIcon: .textSize, accessibilityIdentifier: "catalogue.orb.size"
            )
            heading("From center")
            OrbSlider(
                value: $timing, range: -300...300, defaultValue: 0, origin: .center, label: "Caption timing",
                valueText: "\(Int(timing)) ms", systemIcon: .captions, minCaption: "Earlier", maxCaption: "Later"
            )
            heading("In a row")
            OrbSlider(
                value: $sky, range: 0...2, step: 1, style: .row, label: "Sky", valueText: SkyDensity.allCases[Int(sky)].label
            )
            heading("On camera")
            OrbSlider(value: $volume, range: 0...150, defaultValue: 100, style: .compact, label: "Speed", valueText: "\(Int(volume))%")
            heading("Disabled")
            OrbSlider(value: $volume, range: 0...150, label: "Music", valueText: "\(Int(volume))%").disabled(true)
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
