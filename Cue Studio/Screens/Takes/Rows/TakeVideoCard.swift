//
//  TakeVideoCard.swift
//  Cue Studio
//

import SwiftUI

/// A video in the Takes grid: its best take as a 9:16 poster with the stage on top ("● READY", and
/// "×3" when it has several takes), the title at the bottom over four steps lit up to the stage,
/// and under it the platform and length ("● TIKTOK · 1:02").
struct TakeVideoCard: View {
    let video: TakeVideo

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 7) {
            Color.clear
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .overlay { poster }
                .overlay { shade }
                .overlay(alignment: .top) { topRow }
                .overlay(alignment: .bottomLeading) { bottom }
                .clipShape(shape)
                .overlay(shape.strokeBorder(video.stage == .pick ? Palette.acc.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
            hud
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var poster: some View {
        if let best = video.best {
            TakeThumbnail(take: best)
        }
    }

    private var shade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.25), location: 0),
                .init(color: .clear, location: 0.25),
                .init(color: .clear, location: 0.5),
                .init(color: .black.opacity(0.85), location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var topRow: some View {
        HStack(spacing: 6) {
            TakeStageBadge(stage: video.stage)
            Spacer(minLength: 0)
            if video.takes.count > 1 {
                Text("×\(video.takes.count)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Palette.Takes.posterPill, in: Capsule())
            }
        }
        .padding(8)
    }

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(video.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            HStack(spacing: 3) {
                ForEach(TakeStage.allCases) { step in
                    Capsule()
                        .fill(step <= video.stage ? video.stage.pillTint : Color.white.opacity(0.18))
                        .frame(height: 3)
                }
            }
        }
        .padding(10)
    }

    private var hud: some View {
        HStack(spacing: 5) {
            ColorDot(color: video.platform?.tint ?? Palette.Platform.neutral, size: 5)
            Text(hudText)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
        .tracking(0.4)
        .foregroundStyle(Palette.ink2)
        .padding(.horizontal, 2)
    }

    private var hudText: String {
        let platform = video.platform?.label ?? String(localized: "Freestyle")
        guard let best = video.best else { return platform }
        return platform + " · " + DurationText.clock(best.duration)
    }

    private var accessibilityText: String {
        var parts = [video.title, video.stage.sentence, hudText]
        if let label = video.takesLabel { parts.append(label) }
        return parts.joined(separator: ", ")
    }
}
