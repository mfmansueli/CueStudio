//
//  FormatTile.swift
//  Cue Studio
//

import SwiftUI

/// One format: its name, what it is for, and its sections in mono ("HOOK › PROBLEM › PRODUCT"). A sponsored ad says it
/// needs brand info; a serious format sits on the quieter surface.
struct FormatTile: View {
    let choice: FormatChoice
    let isSelected: Bool

    var body: some View {
        SelectableCard(isSelected: isSelected, radius: Metrics.tileRadius, background: choice.isSerious ? Palette.surfaceMuted : Palette.surface2) {
            VStack(alignment: .leading, spacing: 4) {
                Text(choice.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if choice.needsBrandBrief {
                    Text("needs brand info")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.aiText)
                }
                Text(choice.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Text(choice.sections.joined(separator: " › "))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? Palette.accText : Palette.inkHint)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
