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
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(SkyMemory.self) private var sky
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(LogbookService.self) private var logbook

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
            .skyBackground()
            // "Your stars": one for each idea sent, and the one on its way.
            .overlay(alignment: .top) { SkyStarsLayer(stars: sky.visible).ignoresSafeArea(edges: .top) }
            .overlay { StarFlightOverlay(flight: sky.flight).ignoresSafeArea() }
            // New scripts get their topic (on this iPhone) once they are long enough to say what they are about.
            .task(id: library.scripts.filter { $0.topic == nil }.map(\.id)) { await tagging.tagUntagged() }
            // The title lives in the content (`ScriptsHeader`), as on the board: no navigation bar on this tab root.
            .toolbar(.hidden, for: .navigationBar)
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
        let groups = viewModel.groups(takeCount: { takes.count(for: $0) })
        return List(selection: $viewModel.selection) {
            // The title with its count and the three round buttons, the card, the platform filters (and the search): free blocks.
            blockRow(top: 4) {
                ScriptsHeader(
                    summaryValues: viewModel.summaryValues(takeCount: { takes.count(for: $0) }),
                    logbookCount: logbook.waiting.count,
                    onLogbook: { presentation.present(.logbook) },
                    onSearch: { viewModel.isSearching.toggle() },
                    onNew: { presentation.present(.newScript) }
                )
            }
            blockRow(top: 16) {
                // The same card as the first visit's: typed or dictated in place, the arrow sends the idea.
                IdeaPromptCard(
                    base: Palette.surface, animatesBackground: animatesPromptBackground,
                    unavailableReason: writerUnavailableReason
                )
                .accessibilityIdentifier("scripts.promptCard")
            }
            blockRow(top: 16, horizontal: 0) {
                // Platform first: it is how creators think about their day.
                PlatformFilterChips(
                    filters: viewModel.filters, selection: $viewModel.filter, count: { viewModel.count(for: $0) }
                )
            }
            blockRow(top: 16) { VoiceNudgeSlot() }
            if viewModel.isSearching {
                blockRow(top: 12) {
                    SearchField(text: $viewModel.query, prompt: "Search scripts")
                        .accessibilityIdentifier("scripts.searchField")
                }
            }
            if let empty = viewModel.emptyResult {
                Section { emptyResultView(empty) }
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    Section {
                        groupHeader(group, showsSelect: index == 0)
                            .listRowInsets(EdgeInsets(top: 22, leading: Metrics.gutter, bottom: 0, trailing: Metrics.gutter))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .selectionDisabled()
                        ForEach(Array(group.scripts.enumerated()), id: \.element.id) { position, script in
                            row(for: script, state: group.state)
                                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 0, trailing: Metrics.gutter))
                                .listRowBackground(
                                    ScriptRowBackground(position: ScriptRowPosition(index: position, count: group.scripts.count))
                                        .padding(.horizontal, Metrics.gutter)
                                )
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listSectionSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
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
        .hidesCueTabBar(viewModel.isSelecting)
        .animation(.smooth(duration: 0.25), value: viewModel.isSelecting)
    }

    /// A free block of the list (no card behind it, no separator): the header, the idea card, the filters.
    private func blockRow<Content: View>(top: CGFloat, horizontal: CGFloat = Metrics.gutter, @ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: 0, trailing: horizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .selectionDisabled()
    }

    // MARK: - Rows

    private func row(for script: Script, state: ScriptState) -> some View {
        let rowView = ScriptRow(
            script: script, state: state, line: line(of: script, state: state), takeCount: takes.count(for: script.id),
            topicColor: tagging.color(for: script), showsTrailing: !viewModel.isSelecting,
            onRecord: { actions.record(script) }
        )
        return Group {
            if viewModel.isSelecting {
                rowView
            } else if state == .recorded {
                // A script with takes goes to its videos; its page is one tap away from there ("From script").
                Button { presentation.selectedTab = .takes } label: { rowView }
                    .buttonStyle(.plain)
            } else {
                // Ready opens its page; a draft opens straight into writing.
                NavigationLink(value: ScriptRoute(scriptID: script.id, startsEditing: state == .draft)) { rowView }
                    .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        .tag(script.id)
        .swipeActions(edge: .trailing) {
            Button { actions.record(script) } label: {
                Label("Record", systemImage: "video.fill")
            }
            .tint(Palette.accAction)
            Button { viewModel.actionsTarget = script } label: {
                Label("More", systemImage: "ellipsis")
            }
            .tint(Palette.neutralAction)
        }
        .contextMenu {
            if state == .recorded {
                Button("Open script", systemImage: "doc.text") { presentation.scriptsPath.append(ScriptRoute(scriptID: script.id)) }
                Divider()
            }
            ScriptActionsMenu(script: script, folders: library.folders, actions: actions)
        } preview: {
            ScriptPreviewCard(script: script, readSeconds: readSeconds(script))
        }
        .accessibilityIdentifier("scripts.row.\(script.id.uuidString)")
    }

    /// "READY TO RECORD · 3" in green, "DRAFTS · 4 — IN PROGRESS" and "RECORDED · 2" quiet (mono 10, wide tracking); Select ends the first one.
    private func groupHeader(_ group: ScriptGroup, showsSelect: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(groupTitle(group))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(group.state == .ready ? Palette.successText : Palette.ink.opacity(0.55))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("scripts.group.\(group.state.rawValue)")
            Spacer()
            if showsSelect {
                Button(viewModel.isSelecting ? "Done" : "Select") {
                    viewModel.toggleSelecting()
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Palette.ink.opacity(0.55))
                .frame(minHeight: Metrics.hitTarget)
                .padding(.vertical, -16)
                .accessibilityIdentifier("scripts.selectButton")
            }
        }
        .textCase(nil)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func groupTitle(_ group: ScriptGroup) -> String {
        switch group.state {
        case .ready: String(localized: "Ready to record · \(group.count)")
        case .draft: String(localized: "Drafts · \(group.count) — In progress")
        case .recorded: String(localized: "Recorded · \(group.count)")
        }
    }

    /// Nothing under the card: the search, the platform or the folder has no script. The way out is the idea card above.
    @ViewBuilder
    private func emptyResultView(_ empty: ScriptsViewModel.EmptyResult) -> some View {
        Group {
            switch empty {
            case .search:
                EmptyState(
                    title: "No matches", message: "Try another word.", actionTitle: "Clear search",
                    action: { viewModel.isSearching = false }, accessibilityPrefix: "scripts.empty"
                )
            case .platform(let platform):
                EmptyState(
                    title: "No \(platform.label) scripts yet", message: "Your next idea can start one.",
                    actionTitle: "Create for \(platform.label)",
                    action: {
                        ideaDraft.platform = platform
                        viewModel.filter = .all
                        ideaDraft.wantsFocus = true
                    },
                    accessibilityPrefix: "scripts.empty"
                )
            case .folder(let name):
                EmptyState(
                    title: "“\(name)” is empty", message: "Move a script here from its menu.", actionTitle: "Show all scripts",
                    action: { viewModel.filter = .all }, accessibilityPrefix: "scripts.empty"
                )
            }
        }
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .selectionDisabled()
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

    private func line(of script: Script, state: ScriptState) -> ScriptRowLine {
        ScriptRowLine(
            script: script, state: state, readSeconds: readSeconds(script), takes: takes.takes(for: script.id)
        ) { [drafts] in drafts?.hasDraft(for: $0) ?? false }
    }

    private func newBlankScript() {
        let script = library.create(
            title: "", text: "", platform: profile.profile.defaultPlatform, language: languages.scriptLanguage, isFinished: false
        )
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
