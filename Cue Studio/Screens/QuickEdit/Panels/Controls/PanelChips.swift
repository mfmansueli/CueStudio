//
//  PanelChips.swift
//  Cue Studio
//

import SwiftUI

/// Choices as chips in a sideways row; each chip can show its label in its own font (the
/// families in Text style).
struct PanelChips<Value: Hashable>: View {
    let options: [PanelOption<Value>]
    let selection: Value?
    var font: (Value) -> Font = { _ in .system(size: 15, weight: .semibold) }
    let identifier: String
    let onSelect: (Value) -> Void

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
                            .font(font(option.value))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(isOn ? Color.black : Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(isOn ? Color.white : Palette.fill, in: Capsule())
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
