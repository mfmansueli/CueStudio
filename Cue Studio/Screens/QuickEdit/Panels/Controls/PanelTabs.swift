//
//  PanelTabs.swift
//  Cue Studio
//

import SwiftUI

/// The tabs of a styling panel, underlined in yellow. On their own row they share the width evenly
/// (every tab in view, each a wide target, at least 16 pt apart so the names never run together),
/// and scroll sideways only when large text doesn't fit.
/// Inline, they sit on another row (Cover's) without their own scroll and separator.
struct PanelTabs: View {
    let tabs: [EditorPanelTab]
    let selection: EditorPanelTab
    var isInline = false
    let onSelect: (EditorPanelTab) -> Void

    var body: some View {
        if isInline {
            row(spacing: 16, fills: false)
        } else {
            ViewThatFits(in: .horizontal) {
                row(spacing: Self.minimumGap, fills: true).padding(.horizontal, 12)
                ScrollView(.horizontal) {
                    row(spacing: 20, fills: false).padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.Editor.separator).frame(height: 0.5) }
        }
    }

    /// The least room between two names: under it they read as one word ("PresetsReveal").
    private static let minimumGap: CGFloat = 16

    private func row(spacing: CGFloat, fills: Bool) -> some View {
        HStack(spacing: spacing) {
            ForEach(tabs) { tab in
                let isOn = tab == selection
                Button { onSelect(tab) } label: {
                    Text(tab.label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(isOn ? Palette.ink : Palette.ink2)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minHeight: Metrics.hitTarget)
                        // Underlines the word, however wide the tab is.
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(isOn ? Palette.acc : .clear).frame(height: 2)
                        }
                        .frame(maxWidth: fills ? .infinity : nil)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("edit.panel.tab.\(tab.rawValue)")
            }
        }
    }
}
