//
//  SettingsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings (11.1): how the app behaves. "Your setup" first, then Create, Your Cue, General, Pro and About, as a grouped list with a
/// search that finds the rows themselves. Every page it opens is pushed (`SettingsRoute`).
struct SettingsView: View {
    @Environment(PreferencesService.self) private var preferences
    @Environment(PresentationService.self) private var presentation
    @Environment(ToastService.self) private var toast

    @State private var query = ""
    @State private var confirmsReset = false

    /// Every row is shown. The privacy policy opens its link when one is set (`AppLinks`), and Cue's own summary of it until then.
    static func isShown(_ entry: SettingsEntry) -> Bool { true }

    var body: some View {
        @Bindable var preferences = preferences
        let bindings = SettingsBindings(prompter: $preferences.prompter, camera: $preferences.camera)
        VStack(spacing: 0) {
            // The search sits under the large title and stays there while it is used: the system's collapses the title and brings a keyboard-sized bar.
            SettingsSearchField(text: $query).padding(.horizontal, 16).padding(.bottom, 4)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                root(bindings)
            } else {
                SettingsSearchResults(query: query, bindings: bindings)
            }
        }
        .skyBackground()
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationDestination(for: SettingsRoute.self) { SettingsDestination(route: $0, bindings: bindings) }
    }

    private func root(_ bindings: SettingsBindings) -> some View {
        List {
            Section {
                SetupSummaryCard(camera: preferences.camera, prompter: preferences.prompter) { presentation.settingsPath.append($0) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            } footer: {
                Text("Tap a value to change it. Platforms may suggest a setup. You choose.")
            }
            section(String(localized: "Create"), [.recording, .prompter, .remote], bindings, footer: String(localized: "Set it up once. Every recording starts from here."))
            section(String(localized: "Your Cue"), [.myCueVoice, .personalize], bindings)
            section(String(localized: "General"), [.languageRegion, .privacy], bindings)
            section(String(localized: "Pro"), [.cuePro, .restorePurchases], bindings)
            section(String(localized: "About"), [.privacyPolicy, .termsOfUse, .acknowledgements, .version], bindings)
            // The app's own row, kept exactly as it was until the product owner decides (v30 does not design it).
            Section {
                Button("Reset Creator Setup") { confirmsReset = true }
                    .buttonStyle(.cueDestructiveTinted())
                    .accessibilityIdentifier("creatorSetup.resetButton")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .cueGroupedList()
        .cueActionSheet(
            isPresented: $confirmsReset,
            message: "Camera, microphone, quality, format and teleprompter go back to Cue's defaults. Your scripts, takes and edits stay.",
            actionTitle: "Reset Creator Setup", actionIdentifier: "creatorSetup.confirmResetButton"
        ) {
            preferences.resetCreatorSetup()
            toast.show(String(localized: "Back to Cue's defaults"))
        }
    }

    private func section(_ title: String, _ entries: [SettingsEntry], _ bindings: SettingsBindings, footer: String? = nil) -> some View {
        Section {
            ForEach(entries.filter(Self.isShown)) { SettingsEntryRow(entry: $0, bindings: bindings) }
        } header: {
            CueSectionHeader(verbatim: title)
        } footer: {
            if let footer { Text(footer) }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { SettingsView() }
        .previewEnvironment()
}
#endif
