//
//  SendOffView.swift
//  Cue Studio
//

import SwiftUI

/// The send-off, played once: the video folds into light, a comet carries it along a route to the platform's star,
/// the star flashes as it arrives and "On its way." comes up. Under Reduce Motion it simply arrives.
struct SendOffView: View {
    let video: ExportedVideo
    let destination: ShareDestination
    let onShareAgain: () -> Void
    let onUniverse: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var folded = false
    @State private var comet = 0
    @State private var arrival = 0
    @State private var arrived = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                stars(in: size)
                CometPlayer(path: route(in: size), trigger: comet, duration: 1.5)
                IgniteEffect(trigger: arrival, color: Palette.acc, diameter: 14)
                    .position(target(in: size))
                card(in: size)
                VStack(spacing: 0) {
                    Spacer()
                    texts
                    buttons.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
                }
            }
        }
        .skyBackground()
        .task { await play() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sendoff.sheet")
    }

    // MARK: - Scene

    /// Where each platform's star hangs in the night; the one the video goes to lights up in its own colour.
    private static func place(_ destination: ShareDestination) -> CGPoint {
        switch destination {
        case .linkedin: CGPoint(x: 0.28, y: 0.06)
        case .shorts: CGPoint(x: 0.42, y: 0.12)
        case .tiktok: CGPoint(x: 0.77, y: 0.17)
        case .reels: CGPoint(x: 0.17, y: 0.23)
        case .youtube: CGPoint(x: 0.58, y: 0.27)
        case .stories: CGPoint(x: 0.86, y: 0.31)
        }
    }

    private func target(in size: CGSize) -> CGPoint {
        let unit = Self.place(destination)
        return CGPoint(x: size.width * unit.x, y: size.height * unit.y)
    }

    private func stars(in size: CGSize) -> some View {
        ZStack {
            ForEach(ShareDestination.allCases) { other in
                let unit = Self.place(other)
                let isTarget = other == destination
                VStack(spacing: 6) {
                    Circle()
                        .fill(other.platform.tint)
                        .frame(width: isTarget ? 12 : 9, height: isTarget ? 12 : 9)
                        .shadow(color: other.platform.tint.opacity(isTarget && arrived ? 0.9 : 0.4), radius: isTarget && arrived ? 10 : 4)
                    Text(other.platform.label.uppercased())
                        .font(CueStudioFont.hud)
                        .tracking(1.2)
                        .foregroundStyle(isTarget && arrived ? other.platform.tint : Palette.inkHint)
                }
                .opacity(isTarget ? 1 : 0.7)
                .position(x: size.width * unit.x, y: size.height * unit.y + 14)
            }
        }
        .accessibilityHidden(true)
    }

    /// From the card, up and across to the star: two bends, like a thrown ribbon.
    private func route(in size: CGSize) -> Path {
        let start = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let end = target(in: size)
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: size.width * 0.12, y: size.height * 0.42),
            control2: CGPoint(x: size.width * 0.55, y: end.y + size.height * 0.2)
        )
        return path
    }

    private func card(in size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let width = min(size.width * 0.4, 190)
        return TakeThumbnail(take: video.take)
            .frame(width: width, height: width * 16 / 9)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.acc.opacity(0.7), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Circle().fill(destination.platform.tint).frame(width: 7, height: 7)
                    Text("SHARED").font(CueStudioFont.hud).tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Palette.posterPill, in: Capsule())
                .padding(10)
            }
            .overlay(alignment: .bottomLeading) {
                Text(video.take.scriptTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(10)
            }
            // Folding into light: it shrinks to a point and glows as the comet takes over.
            .scaleEffect(folded ? 0.02 : 1)
            .brightness(folded ? 0.6 : 0)
            .opacity(folded ? 0 : 1)
            .position(x: size.width * 0.5, y: size.height * 0.5)
            .accessibilityHidden(true)
    }

    // MARK: - Words

    private var texts: some View {
        VStack(spacing: 8) {
            Text("SHARED TO \(destination.platform.label.uppercased())")
                .font(CueStudioFont.hud)
                .tracking(1.5)
                .foregroundStyle(Palette.accText)
            Text("On its way.")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.system(size: 16))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            Button(action: onUniverse) {
                HStack(spacing: 6) {
                    Text("It’s now a star in your universe")
                    Image(systemName: "chevron.forward").font(.footnote.weight(.bold))
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sendoff.universeLink")
        }
        .opacity(arrived ? 1 : 0)
        .offset(y: arrived || reduceMotion ? 0 : 16)
        .animation(reduceMotion ? nil : CueMotion.light(duration: 0.6), value: arrived)
    }

    private var detail: String {
        var parts = [DurationText.clock(video.take.duration)]
        if video.hasCaptions { parts.append(String(localized: "captions burned in")) }
        parts.append(String(localized: "no watermark"))
        return parts.joined(separator: " · ")
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: onShareAgain) { Text("Share again") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("sendoff.shareAgain")
            Button(action: onDone) { Text("Done") }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("sendoff.done")
        }
        .opacity(arrived ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.2), value: arrived)
    }

    // MARK: - Motion

    private func play() async {
        guard !reduceMotion else { folded = true; arrived = true; return }
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.easeIn(duration: CueMotion.Duration.foldIntoLight)) { folded = true }
        try? await Task.sleep(for: .milliseconds(450))
        comet += 1
        try? await Task.sleep(for: .milliseconds(1500))
        guard !Task.isCancelled else { return }
        arrival += 1
        Haptics.success()
        withAnimation(.easeOut(duration: 0.4)) { arrived = true }
    }
}
