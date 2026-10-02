//
//  ScriptParagraphView.swift
//  Cue Studio
//

import SwiftUI

/// A paragraph of the script in read mode, under the label of the block it plays and that block's
/// read time. A tap starts writing right there.
struct ScriptParagraphView: View {
    let block: ScriptBlock
    /// The hook runs long: its label and time turn orange.
    let isLongHook: Bool
    /// The read time of the whole block, on its first paragraph.
    let blockSeconds: TimeInterval?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if block.showsLabel {
                HStack(spacing: 8) {
                    Text(block.label)
                        .textCase(.uppercase)
                        .kerning(0.9)
                    Rectangle().fill(Palette.separator).frame(height: 0.5)
                    if let blockSeconds {
                        Text("~\(DurationText.short(blockSeconds))").monospacedDigit()
                    }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(isLongHook ? Palette.warnText : Palette.ink2)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            Text(CueAttributedText.make(block.text, cueFont: .caption.weight(.bold)))
                .font(.system(.title3))
                .lineSpacing(6)
                .foregroundStyle(Palette.ink.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityAction(named: Text("Edit"), onEdit)
        .accessibilityIdentifier("detail.paragraph.\(block.index)")
    }
}
