//
//  UniverseYearSelector.swift
//  Cue Studio
//

import SwiftUI

/// The years of "Your universe" (9.2): a glass capsule, 32 pt high, a year in mono for each; the chosen one is lit. The system's segmented control
/// is too wide and too plain for it.
struct UniverseYearSelector: View {
    let years: [Int]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(years, id: \.self) { year in
                Button { onSelect(year) } label: {
                    Text(String(year))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(year == selected ? Palette.ink : Palette.ink2)
                        .frame(width: 58, height: 32)
                        .background(year == selected ? Color.white.opacity(0.16) : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(year == selected ? .isSelected : [])
                .accessibilityIdentifier("universe.year.\(year)")
            }
        }
        .padding(2)
        .glassEffect(.regular, in: Capsule())
        .animation(.easeOut(duration: 0.2), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("universe.yearPicker")
    }
}
