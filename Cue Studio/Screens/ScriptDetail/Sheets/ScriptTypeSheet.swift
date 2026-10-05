//
//  ScriptTypeSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Script type": the format the script follows. It sets the sections (Hook → Body → CTA…) and
/// the AI suggestions, never the words.
struct ScriptTypeSheet: View {
    let current: ScriptType?
    let onPick: (ScriptType?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    title: String(localized: "Script type"),
                    subtitle: String(localized: "Sets the sections and AI suggestions")
                )
                GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 14) {
                    row(nil, structure: .generic)
                    ForEach(ScriptType.allCases) { type in
                        row(type, structure: type.structure)
                    }
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .cueSheetChrome()
        .presentationDetents([.large])
    }

    private func row(_ type: ScriptType?, structure: ScriptStructure) -> some View {
        Button { onPick(type) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(structure.label).font(.body)
                    Text(structure.blocks.joined(separator: " → "))
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if type == current {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(type == current ? .isSelected : [])
        .accessibilityIdentifier("scriptType.\(type?.rawValue ?? "general")")
    }
}
