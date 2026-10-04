//
//  PaywallExportsMeter.swift
//  Cue Studio
//

import SwiftUI

/// "05 / 05 FREE EXPORTS USED" and a full bar: the free exports are over (the export context only).
/// No watermark talk: nothing is ever locked but exporting.
struct PaywallExportsMeter: View {
    let used: Int
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let padded = { (value: Int) in value.formatted(.number.precision(.integerLength(2...))) }
            HUDLine(values: [String(localized: "\(padded(used)) / \(padded(limit)) free exports used")], tint: Palette.warnText)
            UsageMeter(fraction: Double(used) / Double(max(1, limit)), color: Palette.warn)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.exportsMeter")
    }
}
