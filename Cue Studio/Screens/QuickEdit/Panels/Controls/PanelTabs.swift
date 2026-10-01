//
//  PanelTabs.swift
//  Cue Studio
//

import SwiftUI

/// The tabs of a styling panel, underlined in yellow. Inline, they sit on another row (Text
/// style's scope, on a compact screen) without their own scroll and separator.
struct PanelTabs: View {
    let tabs: [EditorPanelTab]
    let selection: EditorPanelTab
    var isInline = false
    let onSelect: (EditorPanelTab) -> Void

    var body: some View {
        if isInline {
            row
        } else {
            ScrollView(.horizontal) {
                row.padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.editorSeparator).frame(height: 0.5) }
        }
    }

    private var row: some View {
        HStack(spacing: isInline ? 16 : 20) {
            ForEach(tabs) { tab in
                let isOn = tab == selection
                Button { onSelect(tab) } label: {
                    Text(tab.label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(isOn ? Palette.ink : Palette.ink2)
                        .fixedSize()
                        .frame(minHeight: Metrics.hitTarget)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(isOn ? Palette.acc : .clear).frame(height: 2)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("edit.panel.tab.\(tab.rawValue)")
            }
        }
    }
}
