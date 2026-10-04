//
//  MainView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Tabs (Scripts, Takes, Record, Profile, Settings), creation sheets, the prompter and the
/// remote (when this device controls a teleprompter on another one).
struct MainView: View {
    let services: AppServices

    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(PreferencesService.self) private var preferences
    @Environment(CreatorProfileService.self) private var profile
    @Environment(DocumentImportService.self) private var importer
    @Environment(ToastService.self) private var toast
    @Environment(LanguageService.self) private var languages
    @State private var isKeyboardUp = false

    var body: some View {
        @Bindable var presentation = presentation
        VStack(spacing: 0) {
            tabs
            if !presentation.hidesTabBar && !isKeyboardUp {
                CueTabBar(selection: presentation.selectedTab) { presentation.select($0) }
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity)
                    .background(Palette.bg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(CueMotion.card, value: presentation.hidesTabBar)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardUp = false }
        .sheet(item: $presentation.sheet) { sheet in
            sheetContent(sheet)
        }
        .fullScreenCover(item: $presentation.prompter) { launch in
            PrompterView(launch: launch, services: services)
        }
        .fullScreenCover(isPresented: $presentation.showsRemoteController) {
            RemoteControllerView()
        }
    }

    /// The four destinations. The tab bar is ours (below), so the system's is hidden in each tab.
    private var tabs: some View {
        @Bindable var presentation = presentation
        return TabView(selection: tabSelection) {
            Tab("Scripts", systemImage: "doc.text", value: AppTab.scripts) {
                NavigationStack(path: $presentation.scriptsPath) {
                    ScriptsView(library: services.library, toast: services.toast, writer: services.writer, drafts: services.drafts)
                        .navigationDestination(for: ScriptRoute.self) { route in
                            ScriptDetailView(route: route, services: services)
                        }
                }
                .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Takes", systemImage: "film.stack", value: AppTab.takes) {
                NavigationStack { TakesView(services: services) }
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                NavigationStack { ProfileView() }
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack(path: $presentation.settingsPath) {
                    SettingsView()
                        .navigationDestination(for: SettingsRoute.self) { route in
                            switch route {
                            case .languageRegion: LanguageRegionView()
                            case .recording:
                                SettingsRecordingView(preferences: preferences, microphones: services.audio, toast: toast)
                            case .prompter:
                                SettingsPrompterView(preferences: preferences, microphones: services.audio, toast: toast)
                            case .remote: RemoteControlView()
                            case .acknowledgements: AcknowledgementsView()
                            }
                        }
                }
                .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .tint(Palette.accText)
    }

    /// Selecting the record tab presents the sheet and keeps the current tab.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { presentation.selectedTab },
            set: { presentation.select($0) }
        )
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .newScript:
            NewScriptSheet(
                mode: .new,
                onWrite: writeNewScript,
                onImport: { presentation.present(.importScript) }
            )
        case .startRecording:
            StartRecordingSheet(
                mode: .new,
                recent: Array(library.scripts.prefix(StartRecordingSheet.recentLimit)),
                readSeconds: { ReadTime.seconds(for: $0.text, speed: preferences.prompter.speed) },
                onPick: { presentation.openPrompter(scriptID: $0.id, mode: .selfie) },
                onNewScript: { presentation.present(.newScript) },
                onSkip: { presentation.openPrompter(scriptID: nil, mode: .selfie) }
            )
        case .importScript:
            ImportScriptSheet(
                onImported: { document in
                    let script = library.create(
                        title: document.title, text: document.text, platform: profile.profile.defaultPlatform,
                        language: languages.scriptLanguage
                    )
                    presentation.openScript(script.id, editing: true)
                    toast.show(String(localized: "Imported \(document.kind.lowercased()) · \(document.wordCount) words"))
                },
                onPaste: pasteScript
            )
        case .ideas:
            IdeasSheet(
                services: services,
                onEdit: { idea in
                    services.ideaDraft.text = idea.prompt
                    services.ideaDraft.length = idea.length
                },
                onWrite: { idea in services.starter.write(idea: idea.prompt, length: idea.length) }
            )
        case .format:
            FormatSheet(current: services.ideaDraft.format) { services.ideaDraft.format = $0 }
        case .createFor:
            DestinationSheet(current: services.starter.platform) {
                services.ideaDraft.platform = $0
                presentation.sheet = nil
            }
        }
    }

    private func writeNewScript() {
        let script = library.create(title: "", text: "", platform: profile.profile.defaultPlatform, language: languages.scriptLanguage)
        presentation.openScript(script.id, editing: true)
    }

    private func pasteScript() {
        guard let text = importer.clipboardText() else {
            toast.show(String(localized: "Copy your script first, then paste it here"))
            return
        }
        let script = library.create(
            title: ScriptTextNormalizer.suggestedTitle(fileName: nil, text: text),
            text: text,
            platform: profile.profile.defaultPlatform,
            language: languages.scriptLanguage
        )
        presentation.openScript(script.id, editing: true)
        toast.show(String(localized: "Pasted · \(ReadTime.wordCount(in: text)) words"))
    }
}

#if DEBUG
#Preview {
    MainView(services: .preview)
        .previewEnvironment()
}
#endif
