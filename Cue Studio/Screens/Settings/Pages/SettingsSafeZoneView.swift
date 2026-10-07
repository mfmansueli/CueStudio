//
//  SettingsSafeZoneView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter › Social safe zone: whether the camera shows where each app's buttons and captions cover the frame, and which
/// app's it starts with. Custom has margins of its own, 0 to 40% of each edge.
struct SettingsSafeZoneView: View {
    let bindings: SettingsBindings

    private var chosen: SafeZoneChoice { SafeZoneChoice.saved(key: bindings.prompter.wrappedValue.safeZoneKey) }

    var body: some View {
        List {
            Section {
                SettingsListToggle(
                    title: String(localized: "Show safe zone"),
                    detail: String(localized: "Where each app's buttons and captions cover the frame"),
                    isOn: bindings.camera.showsSafeZones
                )
                .accessibilityIdentifier("settings.safeZoneToggle")
                .cardRowBackground()
            }
            Section {
                ForEach(Array(SafeZoneChoice.settingsOptions.enumerated()), id: \.element) { index, choice in
                    Button { bindings.prompter.wrappedValue.safeZoneKey = choice.key } label: {
                        HStack {
                            Text(choice.label).foregroundStyle(Palette.ink)
                            Spacer(minLength: 8)
                            if chosen == choice {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accText)
                            }
                        }
                        .frame(minHeight: Metrics.listRowContent)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen == choice ? .isSelected : [])
                    .accessibilityIdentifier("settings.safeZone.\(choice.key)")
                    .cardRowBackground(position: CardRowPosition(index: index, count: SafeZoneChoice.settingsOptions.count))
                }
            } header: {
                CueSectionHeader("Platform")
            } footer: {
                Text("A guide, not a guarantee · Never recorded")
            }
            if chosen == .custom {
                Section {
                    marginRow(String(localized: "Top"), \.top, SafeZoneMargins.topRange, .first)
                    marginRow(String(localized: "Bottom"), \.bottom, SafeZoneMargins.bottomRange, .middle)
                    marginRow(String(localized: "Left"), \.left, SafeZoneMargins.leftRange, .middle)
                    marginRow(String(localized: "Right"), \.right, SafeZoneMargins.rightRange, .last)
                } header: {
                    CueSectionHeader("Custom margins")
                }
            }
        }
        .cueGroupedList()
        .navigationTitle("Social safe zone")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }

    private func marginRow(
        _ title: String, _ keyPath: WritableKeyPath<SafeZoneMargins, Double>, _ range: ClosedRange<Double>, _ position: CardRowPosition
    ) -> some View {
        let value = bindings.prompter.customSafeZone[dynamicMember: keyPath]
        return SettingsSliderRow(
            title: title, valueText: "\(Int(value.wrappedValue.rounded()))%", value: value, range: range, step: 1,
            identifier: "settings.safeZoneMargin.\(title.lowercased())"
        )
        .cardRowBackground(position: position)
    }
}
