//
//  SettingsValueLabel.swift
//  Cue Studio
//

import SwiftUI

/// The label of a row that opens a page or a menu: the title (and a second line) on the left, what is set on the right. When the
/// value doesn't fit beside the title ("Câmera · Microfone · Fala"), it goes under it, whole (owner, 02/11/2026: no label is ever cut).
struct SettingsValueLabel: View {
    let title: String
    var detail: String?
    var value: String?
    var valueColor: Color = Palette.ink2

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                titles
                Spacer(minLength: 8)
                if let value {
                    valueText(value).fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                titles
                if let value {
                    valueText(value).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(Palette.ink)
            if let detail {
                // The second line wraps to whatever the row leaves it, so only the title and the value decide the layout.
                Text(detail).cueFont(.footnote).foregroundStyle(Palette.ink2)
                    .frame(idealWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func valueText(_ value: String) -> some View {
        Text(verbatim: value).foregroundStyle(valueColor)
    }
}
