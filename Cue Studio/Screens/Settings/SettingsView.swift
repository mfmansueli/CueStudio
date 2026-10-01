//
//  SettingsView.swift
//  Cue Studio
//

import SwiftUI

/// App languages, recording defaults, privacy and purchase recovery, using Profile's list style.
struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(PreferencesService.self) private var preferences
    @Environment(LanguageService.self) private var languages

    @State private var showsPrivacy = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsRoute.languageRegion) {
                    languageRegionRow
                }
                .accessibilityIdentifier("settings.languageRegionButton")
            }
            Section {
                NavigationLink(value: SettingsRoute.creatorSetup) {
                    creatorSetupRow
                }
                .accessibilityIdentifier("settings.creatorSetupButton")
            } header: {
                Text("Creator Setup")
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                    .textCase(nil)
            } footer: {
                Text("Set it up once. Cue remembers how you create.")
            }
            Section {
                Button { showsPrivacy = true } label: {
                    HStack {
                        Text("Privacy & AI data").foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.ink3)
                    }
                }
                .accessibilityIdentifier("settings.privacyButton")
                Button("Restore purchases") {
                    Task {
                        let restored = await store.restore()
                        toast.show(restored ? String(localized: "Purchases restored") : String(localized: "No purchases to restore"))
                    }
                }
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("settings.restorePurchasesButton")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
    }

    private var languageRegionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text("Language & Region").foregroundStyle(Palette.ink)
                    .fixedSize()
                Spacer(minLength: 8)
                Text(verbatim: languages.interfaceLanguage.nativeName)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Language & Region").foregroundStyle(Palette.ink)
                Text(verbatim: languages.interfaceLanguage.nativeName)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "4K · 9:16 · Front · Large text": the usual setup at a glance.
    private var creatorSetupRow: some View {
        let setup = preferences.creatorSetup
        return HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(Palette.acc)
                .frame(width: 28, height: 28)
                .background(Palette.accSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording, teleprompter & remote")
                    .foregroundStyle(Palette.ink)
                Text(setup.summary(of: [.camera, .format, .quality, .textSize]))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack { SettingsView() }
        .previewEnvironment()
}
#endif
