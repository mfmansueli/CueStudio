//
//  PanelChips.swift
//  Cue Studio
//

import SwiftUI

/// Choices as chips in a sideways row; each chip can show its label in its own font (the
/// families in Text style), at a size that grows with the text size.
struct PanelChips<Value: Hashable>: View {
    let options: [PanelOption<Value>]
    let selection: Value?
    /// The chip's font for a value, at a size.
    var font: (Value, CGFloat) -> Font = { _, size in .system(size: size, weight: .semibold) }
    let identifier: String
    let onSelect: (Value) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var textSize: CGFloat = 15

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    let isOn = option.value == selection
                    Button {
                        Haptics.selection()
                        onSelect(option.value)
                    } label: {
                        Text(option.label)
                            .font(font(option.value, textSize))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .frame(minHeight: 38)
                            .background(isOn ? Palette.chipOn : Palette.fill, in: Capsule())
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.cuePress)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(option.key)")
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }
}
