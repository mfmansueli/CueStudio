//
//  BlockChipsView.swift
//  Cue Studio
//

import SwiftUI

/// The script's structure at a glance: one chip per block with its read time. A chip takes the
/// reader to that block; the hook's turns orange when it runs long.
struct BlockChipsView: View {
    let summaries: [BlockSummary]
    let isSerious: Bool
    let hookRunsLong: Bool
    let onTap: (BlockSummary) -> Void

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(summaries) { summary in
                Button { onTap(summary) } label: { chip(summary) }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(Text("Shows this block in the script"))
                    .accessibilityIdentifier("detail.blockChip.\(summary.firstParagraph)")
            }
        }
    }

    private func chip(_ summary: BlockSummary) -> some View {
        let isHook = summary.isOpening && !isSerious
        let foreground: Color = isHook ? (hookRunsLong ? Palette.warnText : Palette.accText) : Palette.ink
        let background: Color = isHook ? (hookRunsLong ? Palette.warnSoft : Palette.accSoft) : Palette.fill
        return HStack(spacing: 6) {
            Text(summary.label)
                .textCase(.uppercase)
                .kerning(0.6)
            Text(DurationText.short(summary.seconds))
                .monospacedDigit()
                .foregroundStyle(foreground.opacity(0.85))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(background, in: Capsule())
        .frame(minHeight: Metrics.hitTarget - 16)
        .contentShape(Capsule())
    }
}

#if DEBUG
#Preview {
    let structure = ScriptType.list.structure
    let blocks = ScriptBlocks.blocks(for: SampleScripts.morningHabits.text, structure: structure, speed: 1)
    BlockChipsView(summaries: ScriptBlocks.summaries(of: blocks), isSerious: false, hookRunsLong: true, onTap: { _ in })
        .padding()
        .background(Palette.surface)
}
#endif
