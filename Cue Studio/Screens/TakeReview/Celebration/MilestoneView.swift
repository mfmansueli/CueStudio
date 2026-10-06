//
//  MilestoneView.swift
//  Cue Studio
//

import SwiftUI

/// A milestone in the creator's universe (1, 10, 25 or 50 videos shared) opens an app icon. Light converges on a
/// point, the point flares with slow rays, and the screen offers the icon for the Home Screen.
struct MilestoneView: View {
    let milestone: Int
    let icon: AppIconChoice
    /// The year the milestone is told in (the sentence says how many videos in it).
    var year = UniverseYears.current()
    /// Whether the icon is free for this creator (Aurora) or comes with Pro.
    let isAvailable: Bool
    let onUse: () -> Void
    let onKeep: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.storyFrozenAt) private var frozenAt
    @State private var start = Date.now

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion || frozenAt != nil)) { context in
                let time = frozenAt ?? (reduceMotion ? MilestoneScript.duration : context.date.timeIntervalSince(start))
                ZStack(alignment: .top) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Palette.accText)
                        .frame(maxWidth: .infinity)
                        .offset(y: 96)
                    hero(time: time).offset(y: 200)
                    VStack(spacing: 10) {
                        Text("A new icon is yours.")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.6)
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(message).font(.system(size: 15)).foregroundStyle(Palette.ink2)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .offset(y: 424)
                    homeScreenRow.offset(y: 548)
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 6) {
                            Button(action: onUse) {
                                Text(isAvailable ? String(localized: "Use \(icon.title)") : String(localized: "Get \(icon.title) with Pro"))
                            }
                                .buttonStyle(.cuePrimary(.large))
                                .accessibilityIdentifier("milestone.use")
                            Button(action: onKeep) {
                                Text("Keep my current icon")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.ink2)
                                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("milestone.keep")
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .frame(height: proxy.size.height)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea()
        .skyBackground(wash: BgWash.milestone, base: Palette.flightNight)
        .task { await haptic() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("milestone.sheet")
    }

    /// "MILESTONE · 25 VIDEOS IN 2026"
    private var eyebrow: String {
        if milestone == 1 { return String(localized: "MILESTONE · FIRST VIDEO IN \(String(year))") }
        return String(localized: "MILESTONE · \(milestone) VIDEOS IN \(String(year))")
    }

    /// "25 videos in 2026 · Deep Space icon unlocked"
    private var message: String {
        if milestone == 1 { return String(localized: "1 video in \(String(year)) · \(icon.title) icon unlocked") }
        return String(localized: "\(milestone) videos in \(String(year)) · \(icon.title) icon unlocked")
    }

    // MARK: - Parts

    /// 200 pt of lilac light with slow rays, the specks falling in, the icon (140 pt, 32 pt corners) popping out of them and the gold ring.
    private func hero(time: Double) -> some View {
        let pose = MilestoneScript.icon(at: time)
        let speck = MilestoneScript.speck(at: time)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.aiText.opacity(0.45), Palette.aiText.opacity(0)], center: .center, startRadius: 0, endRadius: 100))
                .frame(width: 200, height: 200)
            Rays()
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(MilestoneScript.raysAngle(at: time)))
            if let ring = MilestoneScript.ring(at: time) {
                Circle().strokeBorder(Palette.acc.opacity(0.8 * ring.opacity / 0.9), lineWidth: 1.5)
                    .frame(width: 160, height: 160)
                    .scaleEffect(ring.scale)
            }
            ForEach(Array(MilestoneScript.specks.enumerated()), id: \.offset) { _, item in
                Circle()
                    .fill(color(item.tone))
                    .frame(width: item.size, height: item.size)
                    .shadow(color: color(item.tone), radius: 4)
                    .scaleEffect(speck.scale)
                    .offset(x: item.dx * speck.distance, y: item.dy * speck.distance)
                    .opacity(speck.opacity)
            }
            if let name = icon.previewName {
                Image(name).resizable().scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.7), radius: 30, y: 24)
                    .shadow(color: Palette.nightViolet.opacity(0.35), radius: 25)
                    .scaleEffect(pose.scale)
                    .opacity(pose.opacity)
            }
            // The pale ring and the cross are the board's last layers: they cross over the icon.
            let echo = MilestoneScript.echo(at: time)
            if echo.opacity > 0.01 {
                Circle().strokeBorder(Palette.starCream.opacity(0.8 * echo.opacity), lineWidth: 1)
                    .frame(width: 150, height: 150)
                    .scaleEffect(echo.scale)
            }
            let cross = MilestoneScript.cross(at: time)
            if cross.scale > 0.01 { LightCross().frame(width: 220, height: 220).scaleEffect(cross.scale).opacity(cross.opacity) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .accessibilityHidden(true)
    }

    private func color(_ tone: Int) -> Color {
        switch tone {
        case 0: .white
        case 1: Palette.starLilac
        default: Palette.acc
        }
    }

    /// "ON YOUR HOME SCREEN" and a 76 pt glass row of four icons: three plain tiles and the new one, ringed in yellow.
    private var homeScreenRow: some View {
        VStack(spacing: 10) {
            Text("ON YOUR HOME SCREEN")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.inkHint)
            HStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { index in
                    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                    Group {
                        if index == 1, let name = icon.previewName {
                            Image(name).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(index == 1 ? Palette.acc : .clear, lineWidth: 2))
                    .padding(index == 1 ? 3 : 0)
                    .overlay { if index == 1 { RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Palette.acc, lineWidth: 2) } }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .padding(.horizontal, 45)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Haptic

    /// `.success` as the icon lands.
    private func haptic() async {
        guard !reduceMotion, frozenAt == nil else { return }
        start = .now
        try? await Task.sleep(for: .seconds(MilestoneScript.landing))
        if !Task.isCancelled { Haptics.success() }
    }
}

/// Twelve rays, each 8° wide at its foot, in pale gold at 18%, fading out from 30% to 68% of the way (the board's conic gradient, masked).
private struct Rays: View {
    var body: some View {
        let stops: [Gradient.Stop] = (0..<12).flatMap { ray -> [Gradient.Stop] in
            let base = Double(ray) / 12
            let step = 1.0 / 360
            return [
                .init(color: .clear, location: base + 12 * step), .init(color: Palette.starCream.opacity(0.18), location: base + 16 * step),
                .init(color: .clear, location: base + 20 * step),
            ]
        }
        return Circle()
            .fill(AngularGradient(stops: [.init(color: .clear, location: 0)] + stops + [.init(color: .clear, location: 1)], center: .center))
            .mask(RadialGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.3), .init(color: .clear, location: 0.68)],
                center: .center, startRadius: 0, endRadius: 141
            ))
    }
}

/// The cross of light over the icon: two thin bars of pale gold, fading out to their ends, with a glow.
private struct LightCross: View {
    var body: some View {
        let fade = Gradient(stops: [
            .init(color: Palette.starGold.opacity(0), location: 0), .init(color: Palette.starGold.opacity(0.45), location: 0.3),
            .init(color: Palette.starGold, location: 0.5), .init(color: Palette.starGold.opacity(0.45), location: 0.7),
            .init(color: Palette.starGold.opacity(0), location: 1),
        ])
        ZStack {
            Capsule().fill(LinearGradient(gradient: fade, startPoint: .leading, endPoint: .trailing)).frame(height: 1.8)
            Capsule().fill(LinearGradient(gradient: fade, startPoint: .top, endPoint: .bottom)).frame(width: 1.8, height: 154)
        }
        .shadow(color: Palette.starGold.opacity(0.8), radius: 6)
    }
}
