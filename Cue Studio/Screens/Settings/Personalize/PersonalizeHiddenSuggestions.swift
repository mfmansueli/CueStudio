//
//  PersonalizeHiddenSuggestions.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize › Hidden suggestions: the tools the creator asked Cue not to suggest ("Don't suggest this" on an introduction),
/// each with **Show again**, which lets Cue introduce it again some day (its own limits still apply). Shown only while one is hidden.
struct PersonalizeHiddenSuggestions: View {
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(notifications.hiddenFeatures.enumerated()), id: \.element) { index, feature in
                if index > 0 {
                    Divider().overlay(Palette.separator).padding(.leading, 16)
                }
                row(feature)
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
        .animation(.smooth(duration: 0.25), value: notifications.hiddenFeatures)
    }

    private func row(_ feature: FeatureID) -> some View {
        HStack(spacing: 12) {
            Text(feature.name)
                .cueFont(.body)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Show again")) {
                Haptics.light()
                notifications.suggestAgain(feature)
            }
            .buttonStyle(.cueSecondary(.compact, expands: false))
            .accessibilityLabel(Text("Show again: \(feature.name)"))
            .accessibilityIdentifier("settings.hiddenSuggestion.\(feature.rawValue)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: Metrics.hitTarget)
    }
}
