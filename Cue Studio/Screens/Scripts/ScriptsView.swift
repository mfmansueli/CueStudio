//
//  ScriptsView.swift
//  Cue Studio
//

import SwiftUI

/// Home: the Prompt box, always on top, then the script library. Tap opens, swipe for actions, hold
/// to preview.
struct ScriptsView: View {
    @State private var viewModel: ScriptsViewModel

    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(PresentationService.self) private var presentation
    @Environment(PreferencesService.self) private var preferences
    @Environment(CreatorProfileService.self) private var profile
    @Environment(LanguageService.self) private var languages

    init(library: ScriptLibraryService, toast: ToastService) {
        _viewModel = State(initialValue: ScriptsViewModel(library: library, toast: toast))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        content
            .background(Palette.bg)
            .navigationTitle("Scripts")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationSubtitle(viewModel.summary(takeCount: takes.takes.count))
            .toolbar { toolbarContent }
            .alert("New folder", isPresented: $viewModel.isNamingFolder) {
                TextField("Folder name", text: $viewModel.newFolderName)
                Button("Cancel", role: .cancel) {}
                Button("Create") { viewModel.confirmNewFolder() }
            }
            .confirmationDialog(
                viewModel.actionsTarget?.displayTitle ?? "",
                isPresented: Binding(get: { viewModel.actionsTarget != nil }, set: { if !$0 { viewModel.actionsTarget = nil } }),
                titleVisibility: .visible,
                presenting: viewModel.actionsTarget
            ) { script in
                moreActions(for: script)
            }
            .sheet(item: $viewModel.shareTarget) { script in
                ActivityView(items: [script.shareText])
                    .presentationDetents([.medium, .large])
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if library.hasLoaded && library.scripts.isEmpty {
            EmptyLibraryView(
                onPrompt: { presentation.present(.generateScript(.prompt)) },
                onWrite: newBlankScript,
                onImport: { presentation.present(.importScript) },
                onGenerate: { presentation.present(.generateScript(.prompt)) },
                onSkip: { presentation.openPrompter(scriptID: nil, mode: .selfie) }
            )
        } else {
            scriptList
        }
    }

    private var scriptList: some View {
        @Bindable var viewModel = viewModel
        let visible = viewModel.visibleScripts
        let hero = viewModel.isSelecting ? nil : visible.first
        let rest = hero == nil ? visible : Array(visible.dropFirst())
        return List(selection: $viewModel.selection) {
            Section {
                VStack(spacing: 14) {
                    PromptCard(base: Palette.surface, layout: .compact) {
                        presentation.present(.generateScript(.prompt))
                    }
                    .accessibilityIdentifier("scripts.promptCard")
                    SearchField(text: $viewModel.query, prompt: "Search scripts")
                        .accessibilityIdentifier("scripts.searchField")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
                FilterBar(filters: viewModel.filters, selection: $viewModel.filter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()
            }
            if let hero {
                Section {
                    NavigationLink(value: ScriptRoute(scriptID: hero.id)) {
                        HeroScriptCard(
                            script: hero,
                            readSeconds: readSeconds(hero),
                            takeCount: takes.count(for: hero.id),
                            onStudio: { actions.studio(hero) },
                            onRecord: { actions.record(hero) }
                        )
                    }
                    .navigationLinkIndicatorVisibility(.hidden)
                    // Match the UUID selection type, just like the ordinary rows. Without this
                    // tag List also infers a ScriptRoute selection and pushes the hero twice.
                    .tag(hero.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 4, trailing: Metrics.gutter))
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        ScriptActionsMenu(script: hero, folders: library.folders, actions: actions)
                    } preview: {
                        ScriptPreviewCard(script: hero, readSeconds: readSeconds(hero))
                    }
                    .accessibilityIdentifier("scripts.hero")
                }
            }
            if !rest.isEmpty {
                Section {
                    ForEach(rest) { script in
                        row(for: script)
                    }
                } header: {
                    allScriptsHeader
                } footer: {
                    if !viewModel.isSelecting {
                        Text("Tap to open · Swipe for actions · Hold to preview")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if visible.isEmpty {
                Section {
                    Text("No scripts here yet.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                        .selectionDisabled()
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(viewModel.isSelecting ? .active : .inactive))
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isSelecting {
                SelectionBar(
                    count: viewModel.selection.count,
                    folders: library.folders,
                    onMove: { viewModel.moveSelection(to: $0) },
                    onNewFolder: { viewModel.startNewFolder(moving: viewModel.selection) },
                    onDuplicate: viewModel.duplicateSelection,
                    onDelete: viewModel.deleteSelection
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbarVisibility(viewModel.isSelecting ? .hidden : .automatic, for: .tabBar)
        .animation(.smooth(duration: 0.25), value: viewModel.isSelecting)
    }

    private func row(for script: Script) -> some View {
        NavigationLink(value: ScriptRoute(scriptID: script.id)) {
            ScriptRow(
                script: script,
                readSeconds: readSeconds(script),
                showsQuickActions: !viewModel.isSelecting,
                onStudio: { actions.studio(script) },
                onRecord: { actions.record(script) }
            )
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .tag(script.id)
        .swipeActions(edge: .leading) {
            Button { actions.record(script) } label: {
                Label("Record", systemImage: "video.fill")
            }
            .tint(Palette.acc)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { actions.delete(script) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { viewModel.actionsTarget = script } label: {
                Label("More", systemImage: "ellipsis")
            }
            .tint(Palette.neutralAction)
        }
        .contextMenu {
            ScriptActionsMenu(script: script, folders: library.folders, actions: actions)
        } preview: {
            ScriptPreviewCard(script: script, readSeconds: readSeconds(script))
        }
        .accessibilityIdentifier("scripts.row.\(script.id.uuidString)")
    }

    private var allScriptsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("All scripts")
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Spacer()
            Button(viewModel.isSelecting ? "Done" : "Select") {
                viewModel.toggleSelecting()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Palette.acc)
            .accessibilityIdentifier("scripts.selectButton")
        }
        .textCase(nil)
        .padding(.top, 10)
    }

    @ViewBuilder
    private func moreActions(for script: Script) -> some View {
        Button("Record") { actions.record(script) }
        Button("Studio mode") { actions.studio(script) }
        Button("Edit") { actions.edit(script) }
        Button("Duplicate") { actions.duplicate(script) }
        ForEach(library.folders.filter { $0 != script.folder }, id: \.self) { folder in
            Button("Move to “\(folder)”") { actions.move(script, folder) }
        }
        Button("Move to a new folder…") { actions.moveToNewFolder(script) }
        Button("Share") { viewModel.shareTarget = script }
        Button("Delete", role: .destructive) { actions.delete(script) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presentation.present(.newScript)
            } label: {
                Label("New script", systemImage: "plus")
            }
            .tint(Palette.ink)
            .accessibilityIdentifier("scripts.newButton")
        }
    }

    // MARK: - Actions

    private var actions: ScriptActions {
        ScriptActions(
            record: { presentation.openPrompter(scriptID: $0.id, mode: .selfie) },
            studio: { presentation.openPrompter(scriptID: $0.id, mode: .studio) },
            edit: { presentation.scriptsPath.append(ScriptRoute(scriptID: $0.id, startsEditing: true)) },
            duplicate: { viewModel.duplicate($0) },
            move: { viewModel.move([$0.id], to: $1) },
            moveToNewFolder: { viewModel.startNewFolder(moving: [$0.id]) },
            delete: { viewModel.delete($0) },
            setLanguage: { library.setLanguage($1, of: $0.id) }
        )
    }

    private func readSeconds(_ script: Script) -> TimeInterval {
        ReadTime.seconds(for: script.text, speed: preferences.prompter.speed)
    }

    private func newBlankScript() {
        let script = library.create(title: "", text: "", platform: profile.profile.defaultPlatform, language: languages.scriptLanguage)
        presentation.openScript(script.id, editing: true)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ScriptsView(library: AppServices.preview.library, toast: AppServices.preview.toast)
    }
    .previewEnvironment()
}
#endif
