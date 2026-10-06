//
//  TakeVideoRow.swift
//  Cue Studio
//

import SwiftUI

/// One video in the Takes list: its best take's thumbnail in the take's own frame, platform,
/// format and quality, when, and chips for its stage, takes and edit.
struct TakeVideoRow: View {
    let video: TakeVideo
    let whenLabel: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 14) {
            if let best = video.best { thumbnail(best) }
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    ColorDot(color: video.platform?.tint ?? Palette.Platform.neutral, size: 6)
                    Text(video.platform?.label ?? String(localized: "Freestyle")).foregroundStyle(Palette.ink)
                    if let best = video.best {
                        Text("· \(best.aspect.label) · \(best.resolution.label)")
                    }
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                // With the biggest text the platform, format and quality wrap instead of ending in "…".
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                Text(whenLabel)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                chips
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
    }

    private func thumbnail(_ take: Take) -> some View {
        let size = Self.thumbnailSize(for: take.aspect)
        return TakeThumbnail(take: take)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .frame(width: 72, height: 112)
            .background(Palette.Takes.thumbnailWell, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                if take.isBest {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.accInk)
                        .frame(width: 20, height: 20)
                        .background(Palette.acc, in: Circle())
                        .padding(5)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text(DurationText.clock(take.duration))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    // A badge on a thumbnail of fixed size: it follows the text size up to a point.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .background(Palette.Takes.durationBadge, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(5)
            }
    }

    @ViewBuilder
    private var chips: some View {
        FlowLayout(spacing: 5, lineSpacing: 5) {
            stageChip
            if let label = video.takesLabel {
                chip(label, foreground: Palette.ink.opacity(0.85), background: Palette.surface2)
            }
            if video.isEdited {
                chip(String(localized: "Edited"), foreground: Palette.infoText, background: Palette.infoSoft)
            }
        }
        .padding(.top, 2)
    }

    /// "● READY": the stage in its color, in monospaced capitals like the rest of the HUD.
    private var stageChip: some View {
        HStack(spacing: 5) {
            Circle().fill(video.stage.tint).frame(width: 5, height: 5)
            Text(video.stage.badgeLabel).textCase(.uppercase)
        }
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .tracking(0.5)
        .foregroundStyle(video.stage.tint)
        .padding(.horizontal, 8)
        .frame(minHeight: 22)
        .background(Palette.surface2, in: Capsule())
    }

    private func chip(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .background(background, in: Capsule())
    }

    /// The frame of the video inside the 72 × 112 well, as in the design.
    static func thumbnailSize(for aspect: AspectRatio) -> CGSize {
        switch aspect {
        case .portrait: CGSize(width: 63, height: 112)
        case .vertical: CGSize(width: 72, height: 90)
        case .square: CGSize(width: 72, height: 72)
        case .landscape: CGSize(width: 72, height: 41)
        }
    }

    private var accessibilityText: String {
        var parts = [video.title, video.stage.sentence, video.platform?.label ?? String(localized: "Freestyle"), whenLabel]
        if let label = video.takesLabel { parts.append(label) }
        if video.isEdited { parts.append(String(localized: "Edited")) }
        return parts.joined(separator: ", ")
    }
}
