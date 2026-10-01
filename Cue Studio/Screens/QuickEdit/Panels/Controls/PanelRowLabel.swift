//
//  PanelRowLabel.swift
//  Cue Studio
//

import SwiftUI

/// A control's name, with a detail on the right ("Clearer, fuller speech").
struct PanelRowLabel: View {
    let label: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(.subheadline, weight: .semibold))
            Spacer(minLength: 0)
            if let detail {
                Text(detail)
                    .font(.system(.caption))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
