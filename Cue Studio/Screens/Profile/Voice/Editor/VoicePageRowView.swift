//
//  VoicePageRowView.swift
//  Cue Studio
//

import SwiftUI

/// A row of the My Cue Voice page: the field on the left in grey, what Cue knows on the right (or "+ Add · 1 tap" in yellow), a chevron, and a hairline
/// above. Topics show the bar of the world they are in the universe (3 × 14 pt) before each name; the ones only the voice offers have no world and no bar.
struct VoicePageRowView: View {
    let row: VoicePageRow
    let profile: CreatorProfile
    let action: () -> Void

    var body: some View {
        let value = row.value(in: profile)
        Button(action: action) {
            HStack(spacing: 12) {
                Text(row.title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 96, alignment: .leading)
                Group {
                    if value.isEmpty {
                        Text("+ Add · 1 tap").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.accText)
                    } else if row == .topics {
                        topics
                    } else {
                        Text(value).font(.system(size: 16)).foregroundStyle(Palette.ink)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
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

    private var topics: some View {
        let worlds = profile.topics.filter { if case .extra = $0 { false } else { true } }
        return FlowLayout(spacing: 10, lineSpacing: 2) {
            ForEach(profile.topics) { topic in
                HStack(spacing: 6) {
                    if let index = worlds.firstIndex(of: topic) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(OnboardingTopic.color(at: index))
                            .frame(width: Metrics.themeRailWidth, height: Metrics.themeRailChipHeight)
                            .accessibilityHidden(true)
                    }
                    Text(topic.label).font(.system(size: 16)).foregroundStyle(Palette.ink)
                }
            }
        }
    }
}
