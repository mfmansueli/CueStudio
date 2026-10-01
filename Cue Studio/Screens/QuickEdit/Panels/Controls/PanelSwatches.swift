//
//  PanelSwatches.swift
//  Cue Studio
//

import SwiftUI

/// Colors to pick from, the picked one ringed in yellow.
struct PanelSwatches: View {
    let label: String
    let colors: [OverlayColor]
    let selection: OverlayColor?
    let identifier: String
    let onSelect: (OverlayColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(.subheadline, weight: .semibold))
            HStack(spacing: 4) {
                ForEach(colors) { color in
                    let isOn = color == selection
                    Button {
                        Haptics.selection()
                        onSelect(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                            .padding(3)
                            .overlay(Circle().strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 2))
                            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(color.label))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(color.rawValue)")
                }
            }
        }
    }
}
