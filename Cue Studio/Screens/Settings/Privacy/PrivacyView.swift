//
//  PrivacyView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Privacy & AI data: what stays on this iPhone, the permissions, and "Delete my Cue data".
struct PrivacyView: View {
    let bindings: SettingsBindings

    @State private var showsPolicy = false

    private var policyRow: some View {
        HStack {
            Text(SettingsEntry.privacyPolicy.title).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }

    var body: some View {
        List {
            Section {
                SettingsEntryRow(entry: .onDeviceAI, bindings: bindings)
                SettingsEntryRow(entry: .helpImprove, bindings: bindings)
            } footer: {
                Text("Nothing is sold or shared.")
            }
            Section {
                if let url = AppLinks.privacyPolicy {
                    Link(destination: url) { policyRow }.cardRowBackground()
                } else {
                    Button { showsPolicy = true } label: { policyRow }.buttonStyle(.plain).cardRowBackground()
                }
                SettingsEntryRow(entry: .permissions, bindings: bindings)
            }
            Section {
                SettingsEntryRow(entry: .deleteData, bindings: bindings)
            } footer: {
                Text("Asks for confirmation. This can't be undone.")
            }
        }
        .cueGroupedList()
        .confirmsDataErase()
        .navigationTitle("Privacy & AI data")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
        .sheet(isPresented: $showsPolicy) { PrivacySheet() }
    }
}
