//
//  FormatSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Format" (S2d): how Cue builds the script. Auto picks from the idea; each other format brings
/// its own blocks (HOOK · PROBLEM · PRODUCT…). The choice goes on the card.
struct FormatSheet: View {
    let current: ScriptType?
    let onPick: (ScriptType?) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    title: String(localized: "Format"),
                    subtitle: String(localized: "How Cue builds the script. Auto picks from your idea."),
                    onClose: { dismiss() }
                )
                LazyVGrid(columns: columns, spacing: 10) {
                    Button { pick(nil) } label: {
                        FormatTile(
                            title: String(localized: "Auto"), summary: String(localized: "Cue picks from your idea"),
                            blocks: ScriptStructure.generic.blocks, isSerious: false, isSelected: current == nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("format.auto")
                    ForEach(ScriptType.allCases) { type in
                        Button { pick(type) } label: {
                            FormatTile(
                                title: type.structure.label, summary: type.summary, blocks: type.structure.blocks,
                                isSerious: type.structure.isSerious, isSelected: current == type
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("format.\(type.rawValue)")
                    }
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 28, trailing: Metrics.gutter))
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .accessibilityIdentifier("format.sheet")
    }

    private func pick(_ type: ScriptType?) {
        onPick(type)
        dismiss()
    }
}
