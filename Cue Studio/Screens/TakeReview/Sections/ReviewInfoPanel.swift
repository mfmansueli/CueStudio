//
//  ReviewInfoPanel.swift
//  Cue Studio
//

import SwiftUI

/// What a take is (6.3), on the video with no card around it (owner's refinement, 22/10/2026: less to read): a dot and the title in 19 pt,
/// one line "● TikTok · 0:10 ›" that opens the rest ("1080p · 9:16 · 51s shorter than TikTok’s sweet spot · From script v1"), and the
/// pipeline (PICK · EDIT · READY · SHARED ✦) as four bars. The bar of the stage the video is at fills as the review opens, and again when it
/// moves on (the next one lights with a success tap).
struct ReviewInfoPanel: View {
    let take: Take
    let stage: TakeStage
    let lengthFit: LengthFit?
    let scriptVersion: String?
    /// The colour of the take's theme, for the dot before the title.
    var dotColor: Color = Palette.World.warm

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDetails = false
    /// How much of the current stage's bar is drawn: it fills as the review opens and when the stage moves on.
    @State private var stageFill: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            VStack(alignment: .leading, spacing: 2) {
                summaryButton
                if showsDetails {
                    details.transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            stageBar.padding(.top, 6)
        }
        .onAppear { fillStage() }
        .onChange(of: stage) { old, new in
            if new.rawValue > old.rawValue { Haptics.success() }
            fillStage()
        }
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .shadow(color: dotColor.opacity(0.7), radius: 4)
                .accessibilityHidden(true)
            Text(take.scriptTitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if take.isEdited {
                Text("Edited")
                    .textCase(.uppercase)
                    .monoFont(size: 9.5, weight: .heavy)
                    .interfaceTracking(0.5)
                    .foregroundStyle(Palette.infoText)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Palette.infoSoft, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - The line and its details

    private var platformName: String { take.platform?.label ?? String(localized: "Freestyle") }

    /// "● TikTok · 0:10 ›": where it goes and how long it is; a tap opens the rest.
    private var summaryButton: some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { showsDetails.toggle() }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(take.platform?.tint ?? Palette.Platform.neutral)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(verbatim: "\(platformName) · \(DurationText.clock(take.duration))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink2)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.ink2)
                    .rotationEffect(.degrees(showsDetails ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(showsDetails ? "Hides the details" : "Shows the details"))
        .accessibilityIdentifier("review.summary")
    }

    /// "1080p · 9:16 · 51s shorter than TikTok’s sweet spot · From script v1"
    private var details: some View {
        var parts = [take.resolution.label, take.aspect.label]
        if let lengthFit { parts.append(Self.fitText(lengthFit, platform: platformName)) }
        if let scriptVersion { parts.append(String(localized: "From script \(scriptVersion)")) }
        return Text(verbatim: parts.joined(separator: " · "))
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("review.lengthFit")
    }

    /// How the length does against the network: it fits, or how far off it is.
    static func fitText(_ fit: LengthFit, platform: String) -> String {
        switch fit.verdict {
        case .fits: String(localized: "Fits \(platform)")
        case .under(let gap): String(localized: "\(DurationText.remaining(gap)) shorter than \(platform)’s sweet spot")
        case .over(let gap): String(localized: "\(DurationText.remaining(gap)) longer than \(platform)’s sweet spot")
        }
    }

    // MARK: - The stages

    private func fillStage() {
        guard !reduceMotion else {
            stageFill = 1
            return
        }
        stageFill = 0
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.15)) { stageFill = 1 }
    }

    private var stageBar: some View {
        let labels = TakeStage.allCases.map { $0 == .shared ? "\($0.stepLabel.uppercased()) ✦" : $0.stepLabel.uppercased() }
        return HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let isDone = index < stage.rawValue
                let isCurrent = index == stage.rawValue
                VStack(spacing: 6) {
                    Capsule()
                        .fill(isDone ? Color.white.opacity(0.85) : Palette.fill)
                        .overlay(alignment: .leading) {
                            if isCurrent {
                                GeometryReader { proxy in
                                    Capsule().fill(stage.pillTint).frame(width: proxy.size.width * stageFill)
                                }
                            }
                        }
                        .frame(height: 3)
                    Text(label)
                        .monoFont(size: 10, weight: .semibold)
                        .interfaceTracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isCurrent ? stage.pillTint : Palette.inkHint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stage"))
        .accessibilityValue(Text(labels.indices.contains(stage.rawValue) ? labels[stage.rawValue] : ""))
        .accessibilityIdentifier("review.stageBar")
    }
}
