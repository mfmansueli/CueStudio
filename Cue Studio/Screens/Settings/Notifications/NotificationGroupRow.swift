//
//  NotificationGroupRow.swift
//  Cue Studio
//

import SwiftUI

/// One switch of Settings › Notifications (`NotificationGroup`): its title and, under it, what it sends, in a line.
struct NotificationGroupRow: View {
    let group: NotificationGroup
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).foregroundStyle(Palette.ink)
                if let detail = group.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Palette.success)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: Metrics.hitTarget)
        .accessibilityIdentifier("notifications.group.\(group.rawValue)")
    }
}
