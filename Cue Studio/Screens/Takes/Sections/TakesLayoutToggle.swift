//
//  TakesLayoutToggle.swift
//  Cue Studio
//

import SwiftUI

/// List | Grid, as two icons in a small track: the chosen one on `segmentOn`.
struct TakesLayoutToggle: View {
    @Binding var layout: TakeLayout

    var body: some View {
        HStack(spacing: 2) {
            ForEach([TakeLayout.list, .grid]) { option in
                let isOn = layout == option
                Button { layout = option } label: {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOn ? Palette.ink : Palette.ink2)
                        .frame(width: 40, height: 30)
                        .background(isOn ? Palette.segmentOn : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.label))
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("takes.layout.\(option.rawValue)")
            }
        }
        .padding(2)
        .background(Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
    }
}
