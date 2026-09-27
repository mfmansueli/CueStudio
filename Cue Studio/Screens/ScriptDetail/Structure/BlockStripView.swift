//
//  BlockStripView.swift
//  Cue Studio
//

import SwiftUI

/// The script's structure at a glance: one chip per block with its read time. The hook chip opens
/// hook options and turns orange when the hook runs long.
struct BlockStripView: View {
    let summaries: [BlockSummary]
    let isSerious: Bool
    let hookRunsLong: Bool
    let onHookTap: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(summaries) { summary in
                    if summary.isOpening && !isSerious {
                        Button(action: onHookTap) { chip(summary, style: hookRunsLong ? .warning : .hook) }
                            .buttonStyle(.plain)
                            .accessibilityHint(Text("Shows other hooks"))
                            .accessibilityIdentifier("detail.hookChip")
                    } else {
                        chip(summary, style: .plain)
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private enum ChipStyle { case plain, hook, warning }

    private func chip(_ summary: BlockSummary, style: ChipStyle) -> some View {
        let (foreground, background): (Color, Color) = switch style {
        case .plain: (Palette.ink.opacity(0.7), Palette.surface)
        case .hook: (Palette.acc, Palette.acc.opacity(0.12))
        case .warning: (Palette.warn, Palette.warnSoft)
        }
        return HStack(spacing: 6) {
            Text(summary.label)
                .textCase(.uppercase)
                .kerning(0.6)
            Text(DurationText.short(summary.seconds))
                .monospacedDigit()
                .opacity(0.7)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(background, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    let structure = ScriptType.list.structure
    let blocks = ScriptBlocks.blocks(for: SampleScripts.morningHabits.text, structure: structure, speed: 1)
    BlockStripView(summaries: ScriptBlocks.summaries(of: blocks), isSerious: false, hookRunsLong: true, onHookTap: {})
        .padding(.vertical)
        .background(Palette.bg)
}
#endif
