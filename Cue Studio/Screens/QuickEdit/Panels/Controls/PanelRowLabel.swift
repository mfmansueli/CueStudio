//
//  PanelRowLabel.swift
//  Cue Studio
//

import SwiftUI

/// A control's name, with a detail on the right ("Clearer, fuller speech"); at the accessibility text sizes the detail goes under the
/// name, both from the left, so neither is squeezed to a word a line.
struct PanelRowLabel: View {
    let label: String
    var detail: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize, let detail {
            VStack(alignment: .leading, spacing: 2) {
                name
                Text(detail)
                    .font(.system(.caption))
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                name
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

    private var name: some View {
        Text(label)
            .font(.system(.subheadline, weight: .semibold))
    }
}
