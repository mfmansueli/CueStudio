//
//  SettingsTile.swift
//  Cue Studio
//

import SwiftUI

/// One of the three pages under "Your setup" (Recording, Prompter, Remote): an icon, its name and
/// a line of what is set.
struct SettingsTile: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.accText)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
