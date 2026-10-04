//
//  SettingsView.swift
//  Cue Studio
//

import SwiftUI

/// How the app behaves (v26): the "Your setup" card with what every recording starts from, the
/// three pages under it (Recording, Prompter, Remote), then General, Purchases & About and Reset.
struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(PreferencesService.self) private var preferences
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation
    @Environment(RemoteControlService.self) private var remote

    @State private var showsPrivacy = false
    @State private var confirmsReset = false

    var body: some View {
        let setup = preferences.creatorSetup
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("How you record, every time.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)
                SetupSummaryCard(
                    setup: setup,
                    onOpenRecording: { presentation.settingsPath.append(.recording) },
                    onOpenPrompter: { presentation.settingsPath.append(.prompter) }
                )
                tiles(setup)
                Text("Set it up once. Cue remembers how you create.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)

                heading(String(localized: "General"))
                GroupedCard(dividerInset: 58) {
                    NavigationLink(value: SettingsRoute.languageRegion) {
                        SettingsRow(
                            systemImage: "globe", title: String(localized: "Language & Region"),
                            value: languages.interfaceLanguage.nativeName
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.languageRegionButton")
                    NavigationLink(value: SettingsRoute.personalize) {
                        SettingsRow(
                            systemImage: "sparkles", tint: Palette.aiText, title: String(localized: "Personalize"),
                            detail: String(localized: "App icon · starry sky · celebrations"), badge: String(localized: "NEW")
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.personalizeButton")
                    Button { showsPrivacy = true } label: {
                        SettingsRow(systemImage: "lock.fill", tint: Palette.neutralAction, title: String(localized: "Privacy & AI data"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.privacyButton")
                }

                heading(String(localized: "Purchases & About"))
                GroupedCard(dividerInset: 58) {
                    Button {
                        Task {
                            let restored = await store.restore()
                            toast.show(restored ? String(localized: "Purchases restored") : String(localized: "No purchases to restore"))
                        }
                    } label: {
                        SettingsRow(
                            systemImage: "arrow.clockwise", tint: Palette.neutralAction,
                            title: String(localized: "Restore purchases"), showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.restorePurchasesButton")
                    NavigationLink(value: SettingsRoute.acknowledgements) {
                        SettingsRow(systemImage: "heart.text.square", tint: Palette.neutralAction, title: String(localized: "Acknowledgements"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.acknowledgementsButton")
                }

                Button("Reset Creator Setup") { confirmsReset = true }
                    .buttonStyle(.cueDestructiveTinted())
                    .padding(.top, 10)
                    .accessibilityIdentifier("creatorSetup.resetButton")
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
        .confirmationDialog("Reset Creator Setup?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset Creator Setup", role: .destructive) {
                preferences.resetCreatorSetup()
                toast.show(String(localized: "Back to Cue's defaults"))
            }
            .accessibilityIdentifier("creatorSetup.confirmResetButton")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera, microphone, quality, format and teleprompter go back to Cue's defaults. Your scripts, takes and edits stay.")
        }
    }

    // MARK: - Pieces

    /// Recording · Prompter · Remote, with what is set in each.
    private func tiles(_ setup: CreatorSetup) -> some View {
        HStack(spacing: 10) {
            tile(
                .recording, "video", String(localized: "Recording"),
                "\(setup.label(for: .camera)) · \(setup.microphone.label)", "recording"
            )
            tile(
                .prompter, "text.alignleft", String(localized: "Prompter"),
                "\(preferences.prompter.scrollMode.shortLabel) · \(Int(setup.textSize.rounded())) pt", "prompter"
            )
            tile(
                .remote, "iphone.radiowaves.left.and.right", String(localized: "Remote"),
                remote.state.isConnected ? String(localized: "Connected") : String(localized: "Off"), "remote"
            )
        }
    }

    private func tile(_ route: SettingsRoute, _ image: String, _ title: String, _ detail: String, _ id: String) -> some View {
        NavigationLink(value: route) {
            SettingsTile(systemImage: image, title: title, detail: detail)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.\(id)Tile")
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(CueStudioFont.hud)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.ink2)
            .padding(EdgeInsets(top: 10, leading: 4, bottom: 0, trailing: 4))
    }
}

#if DEBUG
#Preview {
    NavigationStack { SettingsView() }
        .previewEnvironment()
}
#endif
