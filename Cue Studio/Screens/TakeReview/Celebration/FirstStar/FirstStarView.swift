//
//  FirstStarView.swift
//  Cue Studio
//

import SwiftUI

/// The first take (1.7): it shows "✓ SAVED", folds into light, a comet carries it to the creator's universe and it lights the first star, joined to YOU;
/// then "Your universe has its first star." comes in word by word. Told once, after the first take Cue ever recorded. The story is `FirstStarScript`
/// (the board's keyframes); the app plays it once and holds, with the orbits still turning.
struct FirstStarView: View {
    let take: Take
    let onStudio: () -> Void
    let onEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.storyFrozenAt) private var frozenAt
    @Environment(PersonalizationService.self) private var personalization
    @State private var start = Date.now

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion && frozenAt == nil)) { context in
                let world = frozenAt ?? (reduceMotion ? FirstStarScript.hold : context.date.timeIntervalSince(start))
                let story = min(world, FirstStarScript.hold)
                content(story: story, world: world, in: proxy.size)
            }
        }
        .ignoresSafeArea()
        .background {
            // The board's own night (`#06070D` under a violet light behind the universe), and the sky over it.
            ZStack {
                BgWash(lights: BgWash.firstStar, base: Palette.Flight.nightDeep)
                StarfieldView(density: personalization.sky)
            }
            .ignoresSafeArea()
        }
        .task { await haptic() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstStar.sheet")
    }

    private func content(story: Double, world: Double, in size: CGSize) -> some View {
        // The board is 390 pt wide: the scene sits in the middle of the screen, and the texts and buttons hold to the bottom.
        let across = (size.width - 390) / 2
        let down = max(0, size.height - 844)
        return ZStack(alignment: .topLeading) {
            FirstStarScene(story: story, world: world, reduceMotion: reduceMotion)
                .frame(width: 390, height: 520)
                .offset(x: across)
            takePoster(at: story).offset(x: across)
            texts(at: story).offset(y: 474 + down)
            VStack(spacing: 0) {
                Spacer()
                buttons(at: story)
            }
            .frame(height: size.height)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    // MARK: - The take

    /// The take, 70 × 124 pt at the left, shrinking toward its top centre as it folds into light.
    private func takePoster(at story: Double) -> some View {
        let pose = FirstStarScript.take(at: story)
        let saved = FirstStarScript.saved(at: story)
        let shape = RoundedRectangle(cornerRadius: pose.radius, style: .continuous)
        return TakeThumbnail(take: take)
            .frame(width: 70, height: 124)
            .overlay(alignment: .bottom) {
                Text("✓ SAVED")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Palette.success)
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(6)
                    .opacity(saved.opacity)
                    .offset(y: saved.lift)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.acc.opacity(0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 15, y: 12)
            .brightness((pose.brightness - 1) * 0.35)
            .scaleEffect(pose.scale, anchor: .top)
            .opacity(pose.opacity)
            .offset(x: 34, y: 300)
            .accessibilityHidden(true)
    }

    // MARK: - Words

    /// "CHAPTER 5 · FIRST STAR", the title coming in word by word (blur 8 → 0, 14 pt up) and the line under it.
    private func texts(at story: Double) -> some View {
        let chapter = FirstStarScript.arrival(startingAt: FirstStarScript.chapterStart.percent, length: FirstStarScript.chapterStart.length, at: story)
        let subtitle = FirstStarScript.arrival(startingAt: FirstStarScript.subtitleStart, length: 10, at: story)
        return VStack(spacing: 8) {
            Text("CHAPTER 5 · FIRST STAR")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.54)
                .foregroundStyle(Palette.acc)
                .opacity(chapter)
                .offset(y: 8 * (1 - chapter))
            title(at: story)
            Text("Saved in Takes. Share it to light your \(String(UniverseYears.current())) universe.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(subtitle)
                .offset(y: 10 * (1 - subtitle))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func title(at story: Double) -> some View {
        let sentence = String(localized: "Your universe has its first star.")
        // A language without spaces between words comes in as one piece.
        let words = sentence.contains(" ") ? sentence.split(separator: " ").map(String.init) : [sentence]
        return WordFlow(spacing: 7, lineSpacing: 0) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let arrived = FirstStarScript.arrival(startingAt: FirstStarScript.wordStart(index), length: 10, at: story)
                Text(verbatim: word)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Palette.ink)
                    .blur(radius: 8 * (1 - arrived))
                    .opacity(arrived)
                    .offset(y: 14 * (1 - arrived))
            }
        }
        // The board's two lines break after "its" (its font is wider than the system's): the title holds to 300 pt.
        .frame(maxWidth: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sentence)
        .accessibilityAddTraits(.isHeader)
    }

    private func buttons(at story: Double) -> some View {
        let studio = FirstStarScript.arrival(startingAt: FirstStarScript.studioStart, length: 8.75, at: story)
        let edit = FirstStarScript.arrival(startingAt: FirstStarScript.editStart, length: 8.75, at: story)
        return VStack(spacing: 6) {
            Button(action: onStudio) { Text("Go to my studio") }
                .buttonStyle(.cuePrimary(.large))
                .overlay { shine(at: story) }
                .opacity(studio)
                .offset(y: 18 * (1 - studio))
                .accessibilityIdentifier("firstStar.studio")
            Button(action: onEdit) {
                Text("Edit this take first")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.plain)
            .opacity(edit)
            .offset(y: 18 * (1 - edit))
            .accessibilityIdentifier("firstStar.edit")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    /// The white band that crosses "Go to my studio" once (77.5–87.5% of the cycle).
    private func shine(at story: Double) -> some View {
        GeometryReader { proxy in
            let phase = FirstStarScript.shine(at: story)
            Rectangle()
                .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 70, height: proxy.size.height * 2)
                .rotationEffect(.degrees(15))
                .position(x: -45 + (proxy.size.width + 90) * phase, y: proxy.size.height / 2)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Haptic

    /// `.success` as the star lights.
    private func haptic() async {
        guard !reduceMotion, frozenAt == nil else { return }
        start = .now
        try? await Task.sleep(for: .seconds(FirstStarScript.landing))
        if !Task.isCancelled { Haptics.success() }
    }
}
