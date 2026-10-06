//
//  SendOffView.swift
//  Cue Studio
//

import SwiftUI

/// "On its way." (8.2), played once: the video's card folds into light, and one star per network (350 ms apart) carries it to that network's planet in
/// the universe; each planet lights and grows by one ("+1"), and a new small star lights beside YOU. The text and the buttons are there from the first
/// frame, as on the board. The scene is the board's 390 × 844 frame, scaled to the screen (`SendOffLayout`, `SendOffScript`). Under Reduce Motion it
/// simply arrives.
struct SendOffView: View {
    let video: ExportedVideo
    let networks: [ShareDestination]
    /// The year's universe with these shares in it.
    let snapshot: UniverseSnapshot
    let onShareAgain: () -> Void
    let onUniverse: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sendOffFrozenAt) private var frozenAt
    @State private var start = Date.now

    private var counts: [Platform: Int] {
        Dictionary(uniqueKeysWithValues: Platform.allCases.map { ($0, snapshot.count(for: $0)) })
    }

    var body: some View {
        GeometryReader { proxy in
            let fit = min(proxy.size.width / SendOffLayout.board.width, proxy.size.height / SendOffLayout.board.height)
            TimelineView(.animation(paused: reduceMotion || frozenAt != nil)) { context in
                let time = frozenAt ?? (reduceMotion ? SendOffScript.end(networks: networks.count) + 1 : context.date.timeIntervalSince(start))
                board(time: time)
                    .frame(width: SendOffLayout.board.width, height: SendOffLayout.board.height)
                    .scaleEffect(fit)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea()
        .skyBackground(wash: BgWash.sendOff)
        .task { await play() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sendoff.sheet")
    }

    /// Everything of the board, placed as the board places it.
    private func board(time: Double) -> some View {
        ZStack(alignment: .topLeading) {
            SendOffMap(networks: networks, counts: counts, time: time)
            card(time: time)
            texts.offset(y: SendOffLayout.textsTop)
            VStack(spacing: 0) {
                Spacer()
                buttons.padding(.bottom, SendOffLayout.buttonsBottom)
            }
            .frame(height: SendOffLayout.board.height)
        }
    }

    // MARK: - Card

    /// The video, 54 × 96 pt under the map: it rises a little, then shrinks into the first star.
    private func card(time: Double) -> some View {
        let fold = SendOffScript.card(at: time)
        let frame = SendOffLayout.card
        let shape = RoundedRectangle(cornerRadius: SendOffLayout.cardRadius, style: .continuous)
        return TakeThumbnail(take: video.take)
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            .scaleEffect(fold.scale)
            .offset(y: fold.y)
            .opacity(fold.opacity)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityHidden(true)
    }

    // MARK: - Words

    private var texts: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.32)
                .foregroundStyle(Palette.acc)
                .accessibilityIdentifier("sendoff.headline")
            Text("On its way.")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            Button(action: onUniverse) {
                HStack(spacing: 6) {
                    Text(universeLine)
                    Image(systemName: "chevron.forward").font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.acc)
                .frame(minHeight: Metrics.hitTarget)
            }
            .buttonStyle(.plain)
            .padding(.top, -6)
            .accessibilityIdentifier("sendoff.universeLink")
        }
        .frame(width: SendOffLayout.board.width - 48)
        .padding(.horizontal, 24)
    }

    /// "SHARED TO 3 NETWORKS", or "SHARED TO TIKTOK".
    private var headline: String {
        if networks.count == 1 { return String(localized: "SHARED TO \(networks[0].platform.label.uppercased())") }
        return String(localized: "SHARED TO \(networks.count) NETWORKS")
    }

    private var detail: String {
        var parts = [DurationText.clock(video.take.duration)]
        if video.hasCaptions { parts.append(String(localized: "captions burned in")) }
        parts.append(String(localized: "no watermark"))
        return parts.joined(separator: " · ")
    }

    /// "A new star in your 2026 universe · TikTok 13"
    private var universeLine: String {
        let year = String(snapshot.year)
        guard let first = networks.first else { return String(localized: "A new star in your \(year) universe") }
        return String(localized: "A new star in your \(year) universe · \(first.platform.label) \(snapshot.count(for: first.platform))")
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button(action: onShareAgain) { Text("Share again") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("sendoff.shareAgain")
            Button(action: onDone) { Text("Done") }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("sendoff.done")
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Haptics

    /// `.success` on each arrival (the first one only when three or more land within 0.7 s).
    private func play() async {
        guard !reduceMotion, frozenAt == nil else { return }
        start = .now
        for moment in SendOffScript.hapticArrivals(networks: networks.count) {
            let wait = moment - Date.now.timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled { return }
            Haptics.success()
        }
    }
}
