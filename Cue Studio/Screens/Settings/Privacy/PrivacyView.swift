//
//  PrivacyView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Privacy & AI data: what stays on this iPhone, the permissions, and "Delete my Cue data".
struct PrivacyView: View {
    let bindings: SettingsBindings

    @State private var showsPolicy = false
    @State private var asksUltra = false

    @Environment(UltraScriptService.self) private var ultra
    @Environment(ScriptStarter.self) private var starter

    private var policyRow: some View {
        HStack {
            Text(SettingsEntry.privacyPolicy.title).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward").cueFont(.footnote, weight: .semibold).foregroundStyle(Palette.ink3)
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }

    var body: some View {
        List {
            Section {
                SettingsEntryRows(entries: [.onDeviceAI, .helpImprove], bindings: bindings)
            } footer: {
                Text(ScriptAIService.hasPrivateCloudComputeEntitlement
                    ? String(localized: "Apple Intelligence can use this iPhone or Private Cloud Compute. Your request and voice preferences may be sent to Apple. Writing examples and imported excerpts stay on this iPhone.")
                    : String(localized: "Nothing is sold or shared."))
                    .foregroundStyle(Palette.ink2)
            }
            if ultra.isAvailable { ultraSection }
            Section {
                if let url = AppLinks.privacyPolicy {
                    Link(destination: url) { policyRow }.cardRowBackground(position: .first)
                } else {
                    Button { showsPolicy = true } label: { policyRow }.buttonStyle(.plain).cardRowBackground(position: .first)
                }
                SettingsEntryRow(entry: .permissions, bindings: bindings, position: .last)
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
        .sheet(isPresented: $asksUltra) { UltraConsentSheet(payload: starter.ultraPreview()) { ultra.consent.grant() } }
    }

    /// Ultra AI, where it is offered: its own permission (turning it on shows the disclosure first; off, nothing more is sent) and, in
    /// Debug, the lab that compares lengths.
    private var ultraSection: some View {
        Section {
            SettingsListToggle(
                title: String(localized: "Ultra AI"), detail: String(localized: "Sent to Google · only when you pick it"),
                isOn: Binding(get: { ultra.consent.isGranted }, set: { allowed in
                    if allowed { asksUltra = true } else { ultra.consent.revoke(); starter.choose(.apple) }
                })
            )
            .accessibilityIdentifier("privacy.ultra")
            #if DEBUG
            NavigationLink { UltraLabView() } label: { Text(verbatim: "Ultra AI · Lab") }
                .accessibilityIdentifier("privacy.ultraLab")
            #endif
        } footer: {
            Text("When it’s on and you pick Ultra AI, your request and voice preferences go to Google, which runs its model, and the draft goes back for the polish. Writing examples, imported excerpts, scripts, videos and audio stay on this iPhone. Turning it off doesn’t change Apple Intelligence.")
                .foregroundStyle(Palette.ink2)
        }
    }
}
