//
//  SettingsListToggle.swift
//  Cue Studio
//

import SwiftUI

/// A switch row: the title, a second line under it when there is one, and the switch.
struct SettingsListToggle: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.success)
        .frame(minHeight: Metrics.listRowContent)
    }
}
