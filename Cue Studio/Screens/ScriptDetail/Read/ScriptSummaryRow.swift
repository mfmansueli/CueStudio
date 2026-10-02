//
//  ScriptSummaryRow.swift
//  Cue Studio
//

import SwiftUI

/// The one line under the title: where the script is for, how long it is, and how that sits with
/// the destination ("In the ideal range", "12s under ideal"). Tapping it opens the script's details.
struct ScriptSummaryRow: View {
    let platform: Platform
    let zone: LengthZone
    let onTap: () -> Void

    var body: some View {
        let color = zone.isInIdealRange || zone.words == 0 ? Palette.accText : Palette.warnText
        Button(action: onTap) {
            FlowLayout(spacing: 10, lineSpacing: 4) {
                HStack(spacing: 6) {
                    ColorDot(color: platform.tint, size: 7)
                    Text("\(platform.label) · \(zone.words) words · \(zone.durationLabel)")
                        .foregroundStyle(Palette.ink2)
                }
                HStack(spacing: 4) {
                    Text(zone.status).fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(color)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Script details"))
        .accessibilityValue(Text("\(platform.label), \(zone.words) words, \(zone.durationLabel). \(zone.status)"))
        .accessibilityIdentifier("detail.summaryRow")
    }
}
