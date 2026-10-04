//
//  VoyageChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 2: "Every video is a voyage." Five galaxies are the platforms; picking one sends a comet from "YOU"
/// along a route to it, and Cue sets the format, the length and the safe zones for that galaxy.
struct VoyageChapter: View {
    let onboarding: OnboardingService
    let onContinue: () -> Void

    @Environment(PlatformRulesService.self) private var rules
    @State private var comet = 0
    @State private var typedLine = ""

    var body: some View {
        @Bindable var onboarding = onboarding
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.voyage.chapterLabel, title: String(localized: "Every video is a voyage."),
                subtitle: String(localized: "Where is your first one headed? Cue sets the format, length and safe zones for that galaxy.")
            )
            .padding(.horizontal, 20)
            GeometryReader { proxy in
                ZStack {
                    GalaxyField(selected: onboarding.platform, topics: onboarding.topics)
                    CometPlayer(path: route(in: proxy.size), trigger: comet, duration: 1.4)
                }
            }
            .frame(minHeight: 220)
            .accessibilityHidden(true)
            Text(typedLine)
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Palette.accText)
                .frame(maxWidth: .infinity, minHeight: 18)
                .accessibilityIdentifier("onboarding.formatLine")
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Platform.primary) { platform in chip(platform) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            Spacer(minLength: 12)
            OnboardingPrimaryButton(
                title: String(localized: "Head to \(onboarding.platform.label)"), identifier: "onboarding.continue", action: onContinue
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .onAppear { choose(onboarding.platform, plays: true) }
    }

    private func chip(_ platform: Platform) -> some View {
        let isPicked = onboarding.platform == platform
        return Button {
            Haptics.selection()
            choose(platform, plays: true)
        } label: {
            HStack(spacing: 8) {
                ColorDot(color: platform.tint, size: 10)
                Text(platform.label)
            }
            .font(.system(size: 17, weight: isPicked ? .semibold : .medium))
            .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.ink)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(isPicked ? Palette.chipOn : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(platform.label))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.platform.\(platform.rawValue)")
    }

    private func choose(_ platform: Platform, plays: Bool) {
        onboarding.platform = platform
        if plays { comet += 1 }
        let preset = rules.preset(for: platform, monetizationGoals: true)
        let line = "\(preset.aspect.label) · \(String(localized: "IDEAL")) \(DurationText.clock(preset.idealRange.lowerBound))–\(DurationText.clock(preset.idealRange.upperBound)) · \(String(localized: "SAFE ZONES ON"))"
        typedLine = ""
        Task {
            for character in line {
                typedLine.append(character)
                try? await Task.sleep(for: .milliseconds(18))
                if onboarding.platform != platform { return }
            }
        }
    }

    /// From "YOU" (bottom left) to the chosen galaxy.
    private func route(in size: CGSize) -> Path {
        let from = GalaxyField.position(of: nil, in: size)
        let to = GalaxyField.position(of: onboarding.platform, in: size)
        var path = Path()
        path.move(to: from)
        path.addCurve(
            to: to, control1: CGPoint(x: from.x + (to.x - from.x) * 0.2, y: from.y - 40),
            control2: CGPoint(x: from.x + (to.x - from.x) * 0.7, y: to.y + (from.y - to.y) * 0.5)
        )
        return path
    }
}

/// The platforms as spiral galaxies, the chosen one grown and bright, the others dim; "YOU" with a moon per topic.
struct GalaxyField: View {
    let selected: Platform
    let topics: [OnboardingTopic]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where each galaxy sits, as a fraction of the field; nil is "YOU".
    static func position(of platform: Platform?, in size: CGSize) -> CGPoint {
        let fractions: [Platform?: CGPoint] = [
            nil: CGPoint(x: 0.2, y: 0.78), .tiktok: CGPoint(x: 0.76, y: 0.2), .reels: CGPoint(x: 0.34, y: 0.1),
            .youtube: CGPoint(x: 0.5, y: 0.42), .shorts: CGPoint(x: 0.82, y: 0.68), .linkedin: CGPoint(x: 0.55, y: 0.82),
        ]
        let fraction = fractions[platform] ?? CGPoint(x: 0.5, y: 0.5)
        return CGPoint(x: size.width * fraction.x, y: size.height * fraction.y)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, size in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                for platform in Platform.primary { drawGalaxy(platform, in: &canvas, size: size, time: time) }
                drawYou(in: &canvas, size: size, time: time)
            }
        }
    }

    private func drawGalaxy(_ platform: Platform, in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = Self.position(of: platform, in: size)
        let isSelected = platform == selected
        let scale: CGFloat = isSelected ? 1.5 : 0.9
        let color = platform.tint
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - 50 * scale, y: center.y - 50 * scale, width: 100 * scale, height: 100 * scale)),
            with: .radialGradient(Gradient(colors: [color.opacity(isSelected ? 0.35 : 0.1), .clear]), center: center, startRadius: 0, endRadius: 50 * scale)
        )
        let spin = time * (isSelected ? 0.3 : 0.12)
        for arm in 0..<3 {
            var spiral = Path()
            for step in 0...40 {
                let t = Double(step) / 40
                let angle = Double(arm) * 2.09 + t * 4.2 + spin
                let radius = 4 + t * 24 * scale
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius * 0.45)
                if step == 0 { spiral.move(to: point) } else { spiral.addLine(to: point) }
            }
            canvas.stroke(spiral, with: .color(color.opacity(isSelected ? 0.75 : 0.28)), lineWidth: isSelected ? 1.4 : 1)
        }
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(isSelected ? Palette.acc : color.opacity(0.6)))
        canvas.draw(
            Text(platform.label.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? color : Palette.inkHint),
            at: CGPoint(x: center.x, y: center.y + 34 * scale)
        )
    }

    private func drawYou(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = Self.position(of: nil, in: size)
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - 40, y: center.y - 40, width: 80, height: 80)),
            with: .radialGradient(Gradient(colors: [Color(hex: 0x9D8CFF).opacity(0.4), .clear]), center: center, startRadius: 0, endRadius: 40)
        )
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)), with: .color(.white))
        for index in topics.indices {
            let angle = Double(index) * 2.1 + time * 0.4
            let moon = CGPoint(x: center.x + CGFloat(cos(angle)) * 26, y: center.y + CGFloat(sin(angle)) * 12)
            canvas.fill(Path(ellipseIn: CGRect(x: moon.x - 3.5, y: moon.y - 3.5, width: 7, height: 7)), with: .color(OnboardingTopic.color(at: index)))
        }
        canvas.draw(
            Text("YOU").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.inkHint),
            at: CGPoint(x: center.x, y: center.y + 28)
        )
    }
}
