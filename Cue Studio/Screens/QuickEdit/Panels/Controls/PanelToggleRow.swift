//
//  PanelToggleRow.swift
//  Cue Studio
//

import SwiftUI

/// A setting with a green switch.
struct PanelToggleRow: View {
    let label: String
    var detail: String?
    let isOn: Bool
    let identifier: String
    let onToggle: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            onToggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(.subheadline, weight: .semibold))
                    if let detail {
                        Text(detail).font(.system(.caption)).foregroundStyle(Palette.ink2)
                    }
                }
                Spacer(minLength: 0)
                PanelSwitch(isOn: isOn)
            }
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier(identifier)
    }
}
