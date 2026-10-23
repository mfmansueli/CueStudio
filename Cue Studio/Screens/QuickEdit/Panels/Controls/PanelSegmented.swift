//
//  PanelSegmented.swift
//  Cue Studio
//

import SwiftUI

/// A row of choices in a rounded well: the picked one gray (or yellow when it's the panel's main
/// choice, like a speed). With five or six, the labels shrink down to 12 pt, then take a second line (a long word in
/// German or Russian); with the largest text sizes more than three choices go in rows of three, so a label is never cut.
struct PanelSegmented<Value: Hashable>: View {
    var label: String?
    var detail: String?
    let options: [PanelOption<Value>]
    let selection: Value?
    var accent = false
    var height: CGFloat = 34
    let identifier: String
    let onSelect: (Value) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Rows of three with the largest text sizes, when there are more than three choices.
    private var wraps: Bool { typeSize.isAccessibilitySize && options.count > 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { PanelRowLabel(label: label, detail: detail) }
            Group {
                if wraps {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 0) {
                        ForEach(options, content: segment)
                    }
                } else {
                    HStack(spacing: 3) {
                        ForEach(options, content: segment)
                    }
                }
            }
            .padding(.horizontal, 3)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func segment(_ option: PanelOption<Value>) -> some View {
        let isOn = option.value == selection
        return Button {
            Haptics.selection()
            onSelect(option.value)
        } label: {
            Text(option.label)
                .font(.system(.footnote, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(12 / 13.5)
                .multilineTextAlignment(.center)
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
        .opacity(option.isEnabled ? 1 : Metrics.disabledOpacity)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("\(identifier).\(option.key)")
    }
}
