//
//  VoicePageRowView.swift
//  Cue Studio
//

import SwiftUI

/// A row of the My Cue Voice page: the field on the left in grey, what Cue knows on the right (or a small "Add" pill in soft yellow, the owner,
/// 03/11/2026: the bold yellow line on every empty row was loud), a chevron, and a
/// hairline above (the line saying where the answer is used is gone: the owner, 03/11/2026, "só está acumulando informações"). Topics show the
/// bar of the world they are in the universe (3 × 14 pt) before each name.
struct VoicePageRowView: View {
    let row: VoicePageRow
    let profile: CreatorProfile
    let action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var labelWidth: CGFloat = 96

    var body: some View {
        let value = row.value(in: profile)
        Button(action: action) {
            HStack(spacing: 12) {
                // The label's column grows with the text size, so a long label wraps instead of being cut.
                Text(row.title)
                    .cueFont(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: labelWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    if value.isEmpty, row == .learned {
                        Text("Nothing yet").cueFont(16).foregroundStyle(Palette.ink2)
                    } else if value.isEmpty {
                        addPill
                    } else if row == .topics {
                        topics
                    } else {
                        Text(value).cueFont(16).foregroundStyle(Palette.ink)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .cueFont(.footnote, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(row.title), \(value.isEmpty ? String(localized: "Add") : value)"))
        .accessibilityIdentifier("voicePage.row.\(row.rawValue)")
    }

    /// "Add" drawn as the app's compact button (the "Add" beside a typed answer), in the accent's soft fill and line (the owner, 03/11/2026:
    /// "esse botão, só que fundinho amarelo"). Drawn, not a button: the whole row is the button.
    private var addPill: some View {
        Text("Add")
            .cueFont(.subheadline, weight: .semibold)
            .foregroundStyle(Palette.accText)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.compactButtonHeight)
            .background(Palette.accSoft, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.accLine, lineWidth: 1))
    }

    private var topics: some View {
        let worlds = profile.topics
        return FlowLayout(spacing: 10, lineSpacing: 2) {
            ForEach(profile.topics) { topic in
                HStack(spacing: 6) {
                    if let index = worlds.firstIndex(of: topic) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(OnboardingTopic.color(at: index))
                            .frame(width: Metrics.themeRailWidth, height: Metrics.themeRailChipHeight)
                            .accessibilityHidden(true)
                    }
                    Text(topic.label).cueFont(16).foregroundStyle(Palette.ink)
                }
            }
        }
    }
}
