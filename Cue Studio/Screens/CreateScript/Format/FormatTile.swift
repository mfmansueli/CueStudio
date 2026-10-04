//
//  FormatTile.swift
//  Cue Studio
//

import SwiftUI

/// One format: its name, what it is for, and its blocks in mono ("HOOK · PROBLEM · PRODUCT").
struct FormatTile: View {
    let title: String
    let summary: String
    let blocks: [String]
    let isSerious: Bool
    let isSelected: Bool

    var body: some View {
        SelectableCard(isSelected: isSelected, radius: Metrics.tileRadius, background: isSerious ? Palette.surfaceMuted : Palette.surface2) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(blocks.joined(separator: " · "))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(isSelected ? Palette.accText : Palette.ink2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(13)
        }
        .accessibilityElement(children: .combine)
    }
}
