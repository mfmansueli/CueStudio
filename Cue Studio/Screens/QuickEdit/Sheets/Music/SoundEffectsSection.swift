//
//  SoundEffectsSection.swift
//  Cue Studio
//

import SwiftUI

/// Cue's sound effects by what they're for (`SoundEffectCategory`): a row of chips picks one group or All, and each group shows
/// under its name, two to a row (one at the accessibility text sizes), so each name and what it's for read whole. Tap one to hear
/// it (it shows it's playing), + to add it at the playhead.
struct SoundEffectsSection: View {
    let viewModel: QuickEditViewModel
    let onAdded: () -> Void
    @State private var category: SoundEffectCategory?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var shown: [SoundEffectCategory] {
        category.map { [$0] } ?? SoundEffectCategory.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelRowLabel(label: String(localized: "Sound effects"), detail: String(localized: "Free to use in your videos · no credit needed"))
            PanelChips(
                options: [PanelOption<SoundEffectCategory?>(nil, String(localized: "All"), key: "all")]
                    + SoundEffectCategory.allCases.map { PanelOption<SoundEffectCategory?>($0, $0.label, systemImage: $0.systemImage, key: $0.rawValue) },
                selection: category, identifier: "edit.effectGroup"
            ) { category = $0 }
            ForEach(shown) { group in
                VStack(alignment: .leading, spacing: 8) {
                    if category == nil {
                        Text(group.label)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(Palette.ink2)
                            .accessibilityAddTraits(.isHeader)
                    }
                    grid(group.effects)
                }
            }
        }
    }

    private func grid(_ effects: [SoundEffect]) -> some View {
        let perRow = typeSize.isAccessibilitySize ? 1 : 2
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: effects.count, by: perRow)), id: \.self) { index in
                GridRow {
                    ForEach(index..<(index + perRow), id: \.self) { position in
                        if position < effects.count {
                            SoundEffectCell(viewModel: viewModel, effect: effects[position], onAdded: onAdded)
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }
}
