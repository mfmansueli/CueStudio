//
//  PanelSegmented.swift
//  Cue Studio
//

import SwiftUI

/// A row of choices in a rounded well: the picked one gray (or yellow when it's the panel's main
/// choice, like a speed). With five or six, the labels shrink down to 12 pt before they'd wrap.
struct PanelSegmented<Value: Hashable>: View {
    var label: String?
    var detail: String?
    let options: [PanelOption<Value>]
    let selection: Value?
    var accent = false
    var height: CGFloat = 34
    let identifier: String
    let onSelect: (Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { PanelRowLabel(label: label, detail: detail) }
            HStack(spacing: 3) {
                ForEach(options) { option in
                    let isOn = option.value == selection
                    Button {
                        Haptics.selection()
                        onSelect(option.value)
                    } label: {
                        Text(option.label)
                            .font(.system(.footnote, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(12 / 13.5)
                            .foregroundStyle(isOn ? (accent ? Palette.accInk : Palette.ink) : Palette.ink2)
                            .frame(maxWidth: .infinity, minHeight: height)
                            .background(
                                isOn ? (accent ? Palette.acc : Palette.segmentOn) : .clear,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                            // Each choice is reached from the whole height of the well: 44 pt.
                            .padding(.vertical, max(3, (Metrics.hitTarget - height) / 2))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.isEnabled)
                    .opacity(option.isEnabled ? 1 : 0.35)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(option.key)")
                }
            }
            .padding(.horizontal, 3)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
