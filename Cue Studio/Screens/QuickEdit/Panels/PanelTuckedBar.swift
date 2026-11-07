//
//  PanelTuckedBar.swift
//  Cue Studio
//

import SwiftUI

/// In the toolbar's place while a styling panel is tucked away on the iPhone SE (`QuickEditViewModel.panelIsTucked`, canvas 2
/// R10 §7.3): the panel's name to bring it back as it was (the item, its tab and style, the playhead all stay), and ✓ to finish.
struct PanelTuckedBar: View {
    let viewModel: QuickEditViewModel
    let panel: EditorPanel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.selection()
                viewModel.untuckPanel()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                    Text(viewModel.panelTitle(panel))
                        .font(.system(.subheadline, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .background(Palette.fill, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.cuePress)
            .accessibilityHint(Text("Shows the panel again"))
            .accessibilityIdentifier("edit.panel.untuck")
            Button {
                Haptics.apply()
                viewModel.closePanel()
            } label: {
                Image(systemName: "checkmark")
                    .font(.editorGlyph(EditorGlyph.control, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .frame(width: Metrics.applyButtonSize, height: Metrics.applyButtonSize)
                    .background(Palette.acc, in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Apply"))
            .accessibilityIdentifier("edit.panel.tuckedApply")
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .background(Palette.Editor.panel)
    }
}
