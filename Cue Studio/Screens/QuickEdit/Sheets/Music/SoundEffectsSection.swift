//
//  SoundEffectsSection.swift
//  Cue Studio
//

import SwiftUI

/// Cue's sound effects by what they're for (`SoundEffectCategory`): a row of chips picks one group or All, and each group shows
/// under its name, two to a row while each of its names fits its half whole (`SoundEffectCell.nameFits`), else one ("Trommelwirbel"
/// on an SE; owner, 02/11/2026: no label is ever cut), and one at the accessibility text sizes. Tap one to hear it (it shows it's
/// playing), + to add it at the playhead.
struct SoundEffectsSection: View {
    let viewModel: QuickEditViewModel
    let onAdded: () -> Void
    @State private var category: SoundEffectCategory?
    /// A group's width, for how many go in a row.
    @State private var width: CGFloat = 0
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
                // The group's width, not the section's: the row of chips above can be wider than the sheet.
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            }
        }
    }

    private func perRow(_ effects: [SoundEffect]) -> Int {
        guard !typeSize.isAccessibilitySize else { return 1 }
        let half = (width - Self.spacing) / 2
        return width == 0 || effects.allSatisfy({ SoundEffectCell.nameFits($0.label, cellWidth: half, typeSize: typeSize) }) ? 2 : 1
    }

    private static let spacing: CGFloat = 8

    private func grid(_ effects: [SoundEffect]) -> some View {
        let perRow = perRow(effects)
        return Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
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
