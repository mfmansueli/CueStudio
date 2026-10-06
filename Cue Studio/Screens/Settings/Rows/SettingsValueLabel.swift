//
//  SettingsValueLabel.swift
//  Cue Studio
//

import SwiftUI

/// The label of a row that opens a page or a menu: the title (and a second line) on the left, what is set on the right.
struct SettingsValueLabel: View {
    let title: String
    var detail: String?
    var value: String?
    var valueColor: Color = Palette.ink2

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(verbatim: value).foregroundStyle(valueColor).lineLimit(1)
            }
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }
}
