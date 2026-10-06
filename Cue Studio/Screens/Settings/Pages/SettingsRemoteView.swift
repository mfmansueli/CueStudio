//
//  SettingsRemoteView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Remote: the state of the remote (grey with none, yellow while waiting, green once connected), a way to connect another
/// device to this teleprompter, and the ways to make this iPhone the remote of another one.
struct SettingsRemoteView: View {
    let bindings: SettingsBindings

    @Environment(RemoteControlService.self) private var remote

    var body: some View {
        List {
            Section {
                RemoteStatusHero(state: remote.state, deviceName: remote.state.deviceName)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                SettingsEntryRow(entry: .connectDevice, bindings: bindings)
            } footer: {
                Text("Both devices need Cue and Wi-Fi or Bluetooth on.")
            }
            Section {
                SettingsEntryRow(entry: .enterCode, bindings: bindings)
                SettingsEntryRow(entry: .scanCode, bindings: bindings)
            } header: {
                CueSectionHeader("Use this iPhone as a remote")
            }
            Section {
                SettingsValueLabel(title: String(localized: "Keyboards and foot pedals"), value: String(localized: "Soon"), valueColor: Palette.ink3)
                    .opacity(0.6)
                    .accessibilityElement(children: .combine)
                    .cardRowBackground()
            } header: {
                CueSectionHeader("Coming next")
            }
        }
        .cueGroupedList()
        .navigationTitle("Remote")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
