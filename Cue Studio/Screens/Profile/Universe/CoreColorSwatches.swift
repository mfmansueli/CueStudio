//
//  CoreColorSwatches.swift
//  Cue Studio
//

import SwiftUI

/// The four colours of the universe's core as round swatches (9.2 sheet, 11.3 Personalize): the chosen one has a white ring and, when
/// `showsNames`, a white name under it. One radio group for VoiceOver.
struct CoreColorSwatches: View {
    @Binding var selection: CoreColor
    var showsNames = true

    var body: some View {
        HStack(spacing: showsNames ? 0 : 10) {
            ForEach(CoreColor.allCases) { color in
                Button {
                    guard selection != color else { return }
                    selection = color
                    Haptics.selection()
                } label: {
                    VStack(spacing: 6) {
                        swatch(color)
                        if showsNames {
                            Text(color.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selection == color ? Palette.ink : Palette.ink2)
                        }
                    }
                    .frame(maxWidth: showsNames ? .infinity : nil, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.label)
                .accessibilityAddTraits(selection == color ? [.isSelected] : [])
                .accessibilityIdentifier("coreColor.\(color.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func swatch(_ color: CoreColor) -> some View {
        let stops = color.stops
        return Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: Color(hex: stops.highlight), location: 0),
                    .init(color: Color(hex: stops.light), location: 0.3),
                    .init(color: Color(hex: stops.body), location: 0.62),
                    .init(color: Color(hex: stops.edge), location: 1),
                ],
                center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0, endRadius: 24
            ))
            .frame(width: 30, height: 30)
            .padding(3)
            .overlay(Circle().strokeBorder(selection == color ? Palette.ink : .clear, lineWidth: 2))
    }
}
