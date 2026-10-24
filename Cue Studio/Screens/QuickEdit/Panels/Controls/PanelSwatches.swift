//
//  PanelSwatches.swift
//  Cue Studio
//

import SwiftUI

/// Colors to pick from (the palette, `OverlayColor.palette`), the picked one ringed in yellow and checked (never only a
/// color); each a 44 pt target, the color as large as `diameter` (the styling panels show them bigger). They wrap onto as
/// many rows as the width needs, so the whole palette is always in view. With `reset`, a color picked over a style's own can
/// go back to it from the label's row.
struct PanelSwatches: View {
    let label: String
    let colors: [OverlayColor]
    let selection: OverlayColor?
    var diameter: CGFloat = 30
    /// "Style's": shown while a color is picked over the style's own, and what it does.
    var reset: (label: String, action: () -> Void)?
    let identifier: String
    let onSelect: (OverlayColor) -> Void

    /// 44 pt targets, 4 pt apart, as many to a row as fit.
    private static let columns = [GridItem(.adaptive(minimum: Metrics.hitTarget, maximum: Metrics.hitTarget), spacing: 4)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(label).font(.system(.subheadline, weight: .semibold))
                Spacer(minLength: 0)
                if let reset {
                    Button(reset.label, action: reset.action)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.accText)
                        .frame(minHeight: Metrics.hitTarget)
                        .accessibilityIdentifier("\(identifier).style")
                }
            }
            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 4) {
                ForEach(colors) { color in
                    let isOn = color == selection
                    Button {
                        Haptics.selection()
                        onSelect(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: diameter, height: diameter)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                            .overlay {
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .font(.system(.caption, weight: .heavy))
                                        .foregroundStyle(color.readableInk.color)
                                }
                            }
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
