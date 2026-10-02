//
//  PanelTiles.swift
//  Cue Studio
//

import SwiftUI

/// Choices as tiles with an icon (Zoom, Crop, Background, Reveal): the picked one outlined in
/// yellow on a yellow wash.
struct PanelTiles<Value: Hashable>: View {
    let options: [PanelOption<Value>]
    let selection: Value?
    let identifier: String
    let onSelect: (Value) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, options.count)), spacing: 8) {
            ForEach(options) { option in
                let isOn = option.value == selection
                Button {
                    Haptics.selection()
                    onSelect(option.value)
                } label: {
                    VStack(spacing: 6) {
                        if let symbol = option.systemImage {
                            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                        }
                        Text(option.label)
                            .font(.system(.footnote, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .background(isOn ? Palette.accTile : Palette.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("\(identifier).\(option.key)")
            }
        }
    }
}
