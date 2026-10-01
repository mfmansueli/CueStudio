//
//  MainView.swift
//  Cue Studio
//

import SwiftUI

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

    var body: some View {
        @Bindable var presentation = presentation
        TabView(selection: tabSelection) {
            Tab("Scripts", systemImage: "doc.text", value: AppTab.scripts) {
                NavigationStack(path: $presentation.scriptsPath) {
                    ScriptsView(library: services.library, toast: services.toast)
                        .navigationDestination(for: ScriptRoute.self) { route in
                            ScriptDetailView(route: route, services: services)
                        }
                }
            }
            Tab("Takes", systemImage: "film.stack", value: AppTab.takes) {
                NavigationStack { TakesView(services: services) }
            }
            // Not a destination: selecting it opens "Start recording".
            Tab(value: AppTab.record) {
                Color.clear
            } label: {
                Label {
                    Text("Record")
                } icon: {
                    Image(uiImage: RecordGlyph.tabImage)
                }
            }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                NavigationStack { ProfileView() }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack(path: $presentation.settingsPath) {
                    SettingsView()
                        .navigationDestination(for: SettingsRoute.self) { route in
                            switch route {
                            case .languageRegion: LanguageRegionView()
                            case .creatorSetup:
                                CreatorSetupView(preferences: preferences, microphones: services.audio, toast: toast)
                            case .acknowledgements: AcknowledgementsView()
                            }
                        }
                }
            }
        }
        .tint(Palette.acc)
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
                onPrompt: { presentation.present(.generateScript(.prompt)) },
                onWrite: writeNewScript,
                onImport: { presentation.present(.importScript) },
                onThemes: { presentation.present(.generateScript(.themes)) },
                onFormats: { presentation.present(.generateScript(.formats)) }
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
        case .generateScript(let tab):
            GenerateScriptSheet(services: services, initialTab: tab) { script in
                presentation.openScript(script.id, editing: true)
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
