//
//  PanelDialChip.swift
//  Cue Studio
//

import SwiftUI

/// A setting as a chip in a row of settings (Adjust's dials, Skin's controls): its name and, once it is off its start, its value
/// in yellow. The picked one is white with black text, like every chosen chip; one that is measuring shows a spinner.
struct PanelDialChip: View {
    let title: String
    var valueText: String?
    let isPicked: Bool
    var isMeasuring = false

    /// The name grows with the text size.
    @ScaledMetric(relativeTo: .subheadline) private var titleSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: titleSize, weight: isPicked ? .semibold : .medium))
            if isMeasuring {
                ProgressView().controlSize(.mini).tint(isPicked ? Palette.chipOnInk : Palette.ink)
            } else if let valueText {
                Text(valueText)
                    .font(.system(.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.accText)
            }
        }
        .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.ink)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(isPicked ? Palette.chipOn : Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
    }
}
