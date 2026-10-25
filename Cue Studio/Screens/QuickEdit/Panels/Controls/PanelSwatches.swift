//
//  PanelSwatches.swift
//  Cue Studio
//

import SwiftUI

/// Colors to pick from (the palette, `OverlayColor.palette`), the picked one ringed in yellow and checked (never only a
/// color); each a 44 pt target, the color as large as `diameter` (the styling panels show them bigger). They wrap onto as
/// many rows as the width needs, so the whole palette is always in view. The video's brand kit colors come first
/// (`brandColors`), a color of the creator's own that is picked shows too, and the last well opens the system's color picker
/// for any other (a brand's exact color). With `reset`, a color picked over a style's own can go back to it from the
/// label's row.
struct PanelSwatches: View {
    let label: String
    let colors: [OverlayColor]
    let selection: OverlayColor?
    var diameter: CGFloat = 30
    /// "Style's": shown while a color is picked over the style's own, and what it does.
    var reset: (label: String, action: () -> Void)?
    let identifier: String
    let onSelect: (OverlayColor) -> Void

    @Environment(\.brandColors) private var brandColors

    /// 44 pt targets, 4 pt apart, as many to a row as fit.
    private static let columns = [GridItem(.adaptive(minimum: Metrics.hitTarget, maximum: Metrics.hitTarget), spacing: 4)]

    /// The brand's colors, then the palette, then the picked one when it is neither.
    private var shown: [OverlayColor] {
        var list = brandColors.filter { !colors.contains($0) }
        list += colors
        if let selection, !list.contains(selection) { list.append(selection) }
        var seen = Set<OverlayColor>()
        return list.filter { seen.insert($0).inserted }
    }

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
                ForEach(shown) { color in
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
                CustomColorWell(selection: selection, diameter: diameter, identifier: "\(identifier).custom", onSelect: onSelect)
            }
        }
    }
}

/// The last well of a palette: the system's color picker, for a color of the creator's own.
struct CustomColorWell: View {
    let selection: OverlayColor?
    let diameter: CGFloat
    let identifier: String
    let onSelect: (OverlayColor) -> Void

    var body: some View {
        ColorPicker(selection: Binding(
            get: { selection?.color ?? .white },
            set: { color in
                let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
                onSelect(.custom(red: Double(red), green: Double(green), blue: Double(blue)))
            }
        ), supportsOpacity: false) {
            Text("Custom color")
        }
        .labelsHidden()
        .scaleEffect(diameter / 28)
        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
        .accessibilityLabel(Text("Custom color"))
        .accessibilityIdentifier(identifier)
    }
}
