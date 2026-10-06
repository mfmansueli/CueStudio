//
//  PanelAdvancedButton.swift
//  Cue Studio
//

import SwiftUI

/// "Advanced" under the essential controls: shows the technical ones.
struct PanelAdvancedButton: View {
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Text(isOpen ? "Hide advanced" : "Advanced")
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(Palette.ink.opacity(0.75))
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(Palette.Editor.separator).frame(height: 0.5) }
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityIdentifier("edit.panel.advanced")
    }
}
