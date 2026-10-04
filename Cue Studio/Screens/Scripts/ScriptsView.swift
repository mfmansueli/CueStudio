//
//  ScriptsView.swift
//  Cue Studio
//

import SwiftUI

/// Home: the idea card, always on top, then the Recent scripts, each at its stage on the way to a
/// posted video. Tap opens, swipe for actions, hold to preview.
struct ScriptsView: View {
    @State private var viewModel: ScriptsViewModel

    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(PresentationService.self) private var presentation
    @Environment(PreferencesService.self) private var preferences
    @Environment(CreatorProfileService.self) private var profile
    @Environment(LanguageService.self) private var languages

    /// Tells the idea card whether Apple Intelligence can write.
    private let writer: ScriptWriting?
    /// Which takes have an edit left open: a row's stage reads it.
    private let drafts: QuickEditDraftStoring?

    init(library: ScriptLibraryService, toast: ToastService, writer: ScriptWriting? = nil, drafts: QuickEditDraftStoring? = nil) {
        _viewModel = State(initialValue: ScriptsViewModel(library: library, toast: toast))
        self.writer = writer
        self.drafts = drafts
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        content
            .background(Palette.bg)
            .navigationTitle("Scripts")
            .toolbarTitleDisplayMode(.inlineLarge)
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
                animatesPromptBackground: animatesPromptBackground,
                unavailableReason: writerUnavailableReason,
                onWrite: newBlankScript,
                onImport: { presentation.present(.importScript) },
                onSkip: { presentation.openPrompter(scriptID: nil, mode: .selfie) }
            )
        } else {
            scriptList
        }
    }

    /// Why Apple Intelligence can't write now (the creator's own words), or nil when it can.
    private var writerUnavailableReason: String? {
        writer?.writingUnavailableReason
    }

    private var scriptList: some View {
        @Bindable var viewModel = viewModel
        let visible = viewModel.visibleScripts
        let continuing = viewModel.filter == .all && viewModel.query.isEmpty ? library.scripts.first?.id : nil
        return List(selection: $viewModel.selection) {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HUDLine(values: viewModel.summaryValues(takeCount: takes.takes.count), separator: " / ")
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("scripts.summary")
                    // The same card as the empty screen's: typed or dictated in place, the arrow writes the script.
                    IdeaPromptCard(
                        base: Palette.surface, animatesBackground: animatesPromptBackground,
                        unavailableReason: writerUnavailableReason
                    )
                    .accessibilityIdentifier("scripts.promptCard")
                    if viewModel.isSearching {
                        SearchField(text: $viewModel.query, prompt: "Search scripts")
                            .accessibilityIdentifier("scripts.searchField")
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
            }
            if !visible.isEmpty {
                Section {
                    ForEach(visible) { script in
                        row(for: script, isContinue: script.id == continuing)
                    }
                } header: {
                    recentHeader
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

    private func row(for script: Script, isContinue: Bool) -> some View {
        NavigationLink(value: ScriptRoute(scriptID: script.id)) {
            ScriptRow(
                script: script,
                status: status(of: script),
                isContinue: isContinue,
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
            .tint(Palette.accAction)
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

    /// "Recent", the filter menu ("All ⌄") and Select.
    private var recentHeader: some View {
        @Bindable var viewModel = viewModel
        return HStack(alignment: .center, spacing: 10) {
            Text("Recent")
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            ScriptFilterMenu(filters: viewModel.filters, selection: $viewModel.filter)
            Spacer()
            Button(viewModel.isSelecting ? "Done" : "Select") {
                viewModel.toggleSelecting()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Palette.accText)
            .accessibilityIdentifier("scripts.selectButton")
        }
        .textCase(nil)
        .padding(.top, 6)
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
                viewModel.isSearching.toggle()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tint(Palette.ink)
            .accessibilityIdentifier("scripts.searchButton")
        }
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

    /// Sheets can leave the home mounted underneath them; do not animate that covered card.
    private var animatesPromptBackground: Bool {
        presentation.selectedTab == .scripts && presentation.scriptsPath.isEmpty
            && presentation.sheet == nil && presentation.prompter == nil
            && !presentation.showsRemoteController && viewModel.shareTarget == nil
            && viewModel.actionsTarget == nil && !viewModel.isNamingFolder
    }

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

    /// Before any take: ready to record, and how long it runs. After: the video's stage.
    private func status(of script: Script) -> ScriptStatus {
        ScriptStatus(takes: takes.takes(for: script.id), readSeconds: readSeconds(script)) { [drafts] in
            drafts?.hasDraft(for: $0) ?? false
        }
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
