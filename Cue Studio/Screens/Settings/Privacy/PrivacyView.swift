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
                    ? AIDisclosure.privateCloud
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
        .sheet(isPresented: $asksUltra) { UltraConsentSheet { ultra.consent.grant() } }
    }

    /// The lab that compares lengths is Debug's only.
    #if DEBUG
    private static let showsUltraLab = true
    #else
    private static let showsUltraLab = false
    #endif

    /// Ultra AI, where it is offered: its own permission (turning it on shows the disclosure first; off, nothing more is sent), everything it
    /// sends (`UltraPrivacyView`) and, in Debug, the lab that compares lengths.
    private var ultraSection: some View {
        Section {
            SettingsListToggle(
                title: String(localized: "Ultra AI"), detail: String(localized: "Sent to Google · only when you pick it"),
                isOn: Binding(get: { ultra.consent.isGranted }, set: { allowed in
                    if allowed { asksUltra = true } else { ultra.consent.revoke(); starter.choose(.apple) }
                })
            )
            .accessibilityIdentifier("privacy.ultra")
            .cardRowBackground(position: .first)
            NavigationLink { UltraPrivacyView() } label: {
                Text("What Ultra AI sends").foregroundStyle(Palette.ink).frame(minHeight: Metrics.listRowContent)
            }
            .accessibilityIdentifier("privacy.ultraDetail")
            .cardRowBackground(position: Self.showsUltraLab ? .middle : .last)
            #if DEBUG
            NavigationLink { UltraLabView() } label: { Text(verbatim: "Ultra AI · Lab").foregroundStyle(Palette.ink) }
                .accessibilityIdentifier("privacy.ultraLab")
                .cardRowBackground(position: .last)
            #endif
        } footer: {
            Text("When it’s on and you pick Ultra AI, your idea, your choices and your My Cue Voice preferences go to Google, which writes the script. Off, nothing more is sent. Turning it off doesn’t change Apple Intelligence.")
                .foregroundStyle(Palette.ink2)
        }
    }
}
