//
//  AppearancePicker.swift
//  Cue Studio
//

import SwiftUI

/// Automatic | Light | Dark, as a segmented track with an icon on each (Settings › Appearance).
struct AppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppAppearance.allCases) { option in
                Button { selection = option } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.symbol).font(.caption.weight(.semibold))
                        Text(option.label).font(.footnote.weight(selection == option ? .semibold : .regular)).lineLimit(1)
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background {
                        if selection == option { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.segmentOn) }
                    }
                    .frame(minHeight: Metrics.hitTarget - 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
                .accessibilityIdentifier("settings.appearance.\(option.rawValue)")
            }
        }
        .padding(2)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.appearancePicker")
    }
}
