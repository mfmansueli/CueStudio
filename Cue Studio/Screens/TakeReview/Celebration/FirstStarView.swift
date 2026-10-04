//
//  FirstStarView.swift
//  Cue Studio
//

import SwiftUI

/// The first take: it folds into light, a comet carries it to the creator's universe, and it lights the first star,
/// joined to "YOU". Told once, after the first take Cue ever recorded.
struct FirstStarView: View {
    let take: Take
    let topics: [OnboardingTopic]
    let onStudio: () -> Void
    let onEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var folded = false
    @State private var comet = 0
    @State private var lit: Date?
    @State private var ignite = 0
    @State private var revealed = false

    private static let born: [String: Date] = [:]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                UniverseCanvas(topics: topics, born: Self.born, star: lit)
                    .frame(width: size.width, height: size.height * 0.5)
                    .position(x: size.width / 2, y: size.height * 0.34)
                    .accessibilityHidden(true)
                CometPlayer(path: route(in: size), trigger: comet, duration: 1.3)
                IgniteEffect(trigger: ignite, color: Palette.acc, diameter: 16)
                    .position(starPoint(in: size))
                poster(in: size)
                VStack(spacing: 0) {
                    Spacer()
                    texts
                    VStack(spacing: 4) {
                        Button(action: onStudio) { Text("Go to my studio") }
                            .buttonStyle(.cuePrimary(.large))
                            .accessibilityIdentifier("firstStar.studio")
                        Button(action: onEdit) {
                            Text("Edit this take first")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Palette.ink2)
                                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("firstStar.edit")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                    .opacity(revealed ? 1 : 0)
                }
            }
        }
        .skyBackground()
        .task { await play() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstStar.sheet")
    }

    // MARK: - Scene

    /// Where the universe canvas puts the star (see `UniverseCanvas`).
    private func starPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + size.width * 0.16, y: size.height * 0.34 - size.height * 0.5 * 0.38)
    }

    private func route(in size: CGSize) -> Path {
        let start = CGPoint(x: size.width / 2, y: size.height * 0.62)
        let end = starPoint(in: size)
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end, control1: CGPoint(x: size.width * 0.1, y: size.height * 0.52), control2: CGPoint(x: size.width * 0.8, y: end.y + size.height * 0.2)
        )
        return path
    }

    private func poster(in size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return TakeThumbnail(take: take)
            .frame(width: 96, height: 170)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.acc.opacity(0.7), lineWidth: 1))
            .scaleEffect(folded ? 0.02 : 1)
            .brightness(folded ? 0.6 : 0)
            .opacity(folded ? 0 : 1)
            .position(x: size.width / 2, y: size.height * 0.62)
            .accessibilityHidden(true)
    }

    private var texts: some View {
        VStack(spacing: 12) {
            Text("CHAPTER 5 · FIRST STAR")
                .font(CueStudioFont.hud)
                .tracking(1.5)
                .foregroundStyle(Palette.accText)
            Text("Your take is saved in Takes, ready to edit and share. Every video you share adds another.")
                .font(.system(size: 17))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed || reduceMotion ? 0 : 14)
    }

    // MARK: - Motion

    private func play() async {
        guard !reduceMotion else { lit = .now.addingTimeInterval(-3); folded = true; revealed = true; return }
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeIn(duration: CueMotion.Duration.foldIntoLight)) { folded = true }
        try? await Task.sleep(for: .milliseconds(450))
        comet += 1
        try? await Task.sleep(for: .milliseconds(1300))
        guard !Task.isCancelled else { return }
        lit = .now
        ignite += 1
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeOut(duration: 0.5)) { revealed = true }
    }
}
