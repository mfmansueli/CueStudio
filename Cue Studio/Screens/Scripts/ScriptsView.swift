//
//  ScriptsView.swift
//  Cue Studio
//

import SwiftUI

/// Home (v30 · 3.1, 3.2): the scripts on top, each at its stage on the way to a posted video, and the AI dock fixed at the bottom
/// (`ScriptsDock`). The title, the search's magnifier, the Logbook and "+" are the system's navigation bar; the magnifier opens the search field
/// at the top of the list, and the dock stays while searching. Tap opens, swipe for actions, hold to preview.
struct ScriptsView: View {
    @State private var viewModel: ScriptsViewModel

    @Environment(ScriptLibraryService.self) private var library
    @Environment(TakeLibraryService.self) private var takes
    @Environment(PresentationService.self) private var presentation
    @Environment(CreatorProfileService.self) private var profile
    @Environment(LanguageService.self) private var languages
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(LogbookService.self) private var logbook
    @Environment(ToastService.self) private var toast
    @Environment(FirstVoyageService.self) private var voyage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The dock's field has the keyboard: the list dims.
    @State private var isDockEditing = false
    /// An action picked in the More menu, run once its popover has gone (it may open the prompter, a page or another sheet).
    @State private var pendingAction: (() -> Void)?
    /// The search field at the top of the list has the keyboard.
    @FocusState private var isSearchFocused: Bool
    /// The magnifier opened the search field; it goes again once it has neither the keyboard nor words.
    @State private var isSearchOpen = false
    /// The field takes the keyboard when it appears (only right after the magnifier, not when a scroll brings it back).
    @State private var focusesSearchOnAppear = false
    /// Whether the dock's first row is folded away by the list scrolling.
    @State private var isDockFolded = false
    /// Reads the scroll for the fold. It changes on every frame of a scroll without redrawing the screen; only `isDockFolded` does.
    @State private var dockFold = DockFold()
    /// Whether there was ever a script: an empty library is then the returning state, not the first use.
    @State private var history: LibraryHistory

    /// Tells the idea card whether Apple Intelligence can write.
    private let writer: ScriptWriting?
    /// Which takes have an edit left open: a row's stage reads it.
    private let drafts: QuickEditDraftStoring?

    init(
        library: ScriptLibraryService, toast: ToastService, writer: ScriptWriting? = nil, drafts: QuickEditDraftStoring? = nil,
        defaults: UserDefaults = .standard
    ) {
        _viewModel = State(initialValue: ScriptsViewModel(library: library, toast: toast))
        _history = State(initialValue: LibraryHistory(defaults: defaults))
        self.writer = writer
        self.drafts = drafts
    }

    /// How much of its colour the list keeps while the dock's field has the keyboard (09 §6: brightness 0.5).
    private static let dockDimLevel = 0.5

    var body: some View {
        @Bindable var viewModel = viewModel
        content
            // The board's "brightness 0.5 + blur 3 pt" (09 §6): every colour at half, so the cards stay cards. (`.brightness(-0.3)` took 0.3 off
            // each channel, which turned every dark card into flat black next to the lighter sky.)
            .colorMultiply(isDockEditing ? Color(white: Self.dockDimLevel) : .white)
            .blur(radius: isDockEditing ? 3 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : CueMotion.dockDim, value: isDockEditing)
            .overlay { if isDockEditing { Color.clear.contentShape(Rectangle()).onTapGesture { endEditing() } } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Selecting has the screen to itself (its bar takes the dock's place). The search keeps the dock: its field is at the top of
                // the list (the owner's call, 6/10/2026).
                if !viewModel.isSelecting {
                    VStack(spacing: 10) {
                        // The first voyage's next step, 10 pt above the dock; the My Cue Voice question waits while it has one.
                        VoyageFloatingTip(place: .scripts, isQuiet: isQuiet)
                        VoiceQuestionTipHost(isQuiet: isQuiet && voyage.floatingStep == nil)
                        ScriptsDock(
                            showsFormat: true, isFolded: isDockFolded, isEditing: $isDockEditing,
                            unavailableReason: writerUnavailableReason
                        )
                        .accessibilityIdentifier(isFirstVisit ? "empty.promptCard" : "scripts.promptCard")
                    }
                    // The list doesn't feel the fold: the room the dock keeps under it stays the same (empty space, which lets touches
                    // through, takes the folded row's place). A list whose end moved with the dock jumped by itself under it, which
                    // unfolded the dock, which moved the list again.
                    .padding(.top, isDockFolded ? ScriptsDock.foldHeight : 0)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // While the search has the keyboard, the dock stays at the bottom under it instead of riding up with it: above the keyboard it
            // covered the results (and "No matches"). It is back in sight as soon as the keyboard goes (a scroll sends it away).
            .ignoresSafeArea(isSearchFocused ? .keyboard : [], edges: .bottom)
            .skyBackground()
            // New scripts get their topic (on this iPhone) once they are long enough to say what they are about.
            .task(id: library.scripts.filter { $0.topic == nil }.map(\.id)) { await tagging.tagUntagged() }
            // A library that has held a script (written, imported, seeded, or already there when the app opened) is never "first use" again.
            .onChange(of: library.scripts.count, initial: true) { _, count in history.note(scriptCount: count) }
            .navigationTitle("Scripts")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar { toolbarItems }
            .alert("New folder", isPresented: $viewModel.isNamingFolder) {
                TextField("Folder name", text: $viewModel.newFolderName)
                Button("Cancel", role: .cancel) {}
                Button("Create") { viewModel.confirmNewFolder() }
            }
            .sheet(item: $viewModel.shareTarget) { script in
                ActivityView(items: [script.shareText])
                    .presentationDetents([.medium, .large])
            }
    }

    /// The first visit: no scripts yet (the dock names the empty prompt card, and the first visit only has its own tip).
    private var isFirstVisit: Bool {
        emptyState.isEmpty
    }

    /// The list, the skeleton, or one of the two empty states.
    private var emptyState: ScriptsEmptyState {
        history.state(hasLoaded: library.hasLoaded, scriptCount: library.scripts.count)
    }

    /// Nothing else has the screen, so a tip may come: no sheet, prompter, toast or keyboard, no selection or search.
    private var isQuiet: Bool {
        presentation.sheet == nil && presentation.prompter == nil && presentation.selectedTab == .scripts
            && presentation.scriptsPath.isEmpty && !isDockEditing && !viewModel.isSelecting && !isSearchFocused
            && toast.message == nil
    }

    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Folds or unfolds the dock's first row as one movement: the row, the glass around it and the end of the list (09 §6).
    private func foldDock(_ folded: Bool) {
        guard folded != isDockFolded else { return }
        withAnimation(reduceMotion ? nil : CueMotion.dockFold) { isDockFolded = folded }
    }

    /// The search field is in the list: opened by the magnifier, or still holding words.
    private var showsSearch: Bool {
        isSearchOpen || !viewModel.query.isEmpty
    }

    /// The magnifier: opens the search field at the top of the list with the keyboard (or gives an open one the keyboard back).
    private func openSearch() {
        if showsSearch {
            isSearchFocused = true
        } else {
            focusesSearchOnAppear = true
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { isSearchOpen = true }
        }
    }

    /// The field goes once it has neither the keyboard nor words (the keyboard dismissed, its ✕, or "Clear search").
    private func closeSearchIfDone() {
        guard isSearchOpen, !isSearchFocused, viewModel.query.isEmpty else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { isSearchOpen = false }
    }

    /// The search's magnifier, Logbook and "+" in the bar's glass.
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Only with scripts to search (the empty Scripts has no list).
            if emptyState == .list {
                Button(action: openSearch) {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel(Text("Search"))
                .accessibilityIdentifier("scripts.searchButton")
            }
            // Always there, the first visit included (the owner's call, 6/10/2026: the empty Scripts has its Logbook too).
            Button { presentation.present(.logbook) } label: {
                CueIconView(.logbook, size: 20)
                    .foregroundStyle(Palette.aiTextStrong)
                    .overlay(alignment: .topTrailing) { logbookBadge }
            }
            .accessibilityLabel(Text("Logbook"))
            .accessibilityValue(Text(logbook.waiting.isEmpty ? "" : "\(logbook.waiting.count)"))
            .accessibilityIdentifier("scripts.logbookButton")
            Button { presentation.present(.newScript) } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(Text("New script"))
            .accessibilityIdentifier("scripts.newButton")
        }
    }

    @ViewBuilder
    private var logbookBadge: some View {
        if !logbook.waiting.isEmpty {
            Text(verbatim: "\(logbook.waiting.count)")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.bg)
                .padding(.horizontal, 4)
                .frame(minWidth: 16, minHeight: 16)
                .background(Palette.aiText, in: Capsule())
                .offset(x: 10, y: -8)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch emptyState {
        case .loading:
            // The structure of the list, with the shine (04 · Global states): no spinner over content.
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in ScriptRowSkeleton() }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .accessibilityIdentifier("scripts.loading")
        case .firstUse, .returning:
            EmptyLibraryView(
                kind: emptyState == .firstUse ? .firstUse : .returning,
                onWrite: newBlankScript,
                onImport: { presentation.present(.importScript) }
            )
        case .list:
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
        return ScrollViewReader { proxy in
            List {
                // The count under the large title ("8 SCRIPTS · 3 READY"), the search (once the magnifier opened it), then the platform filters:
                // free blocks.
                blockRow(top: 0) {
                    HUDLine(values: viewModel.summaryValues(takeCount: { takes.count(for: $0) }))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("scripts.summary")
                }
                .id(Self.listTop)
                if showsSearch {
                    blockRow(top: 14) {
                        SearchField(text: $viewModel.query, prompt: "Search scripts", isFocused: $isSearchFocused)
                            .accessibilityIdentifier("scripts.search")
                            .onAppear {
                                guard focusesSearchOnAppear else { return }
                                focusesSearchOnAppear = false
                                isSearchFocused = true
                            }
                    }
                    .transition(.opacity)
                }
                blockRow(top: 16, horizontal: 0) {
                    // Platform first: it is how creators think about their day.
                    PlatformFilterChips(
                        filters: viewModel.filters, selection: $viewModel.filter, count: { viewModel.count(for: $0) },
                        deleteFolder: { viewModel.deleteFolder($0) }
                    )
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
                            ForEach(Array(group.scripts.enumerated()), id: \.element.id) { position, script in
                                row(for: script, state: group.state)
                                    .listRowInsets(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 0, trailing: Metrics.gutter))
                                    .listRowBackground(
                                        ScriptRowBackground(position: CardRowPosition(index: position, count: group.scripts.count))
                                            .padding(.horizontal, Metrics.gutter)
                                    )
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listSectionSeparator(.hidden)
                    }
                    if viewModel.filter == .all, !viewModel.isSelecting, viewModel.query.isEmpty {
                        // The ideas waiting in the Logbook, at the end of the list.
                        blockRow(top: 22) { ScriptsLogbookSection() }
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .onScrollGeometryChange(for: DockFold.Position.self) { geometry in
                // From the top of the list (0) to the farthest it scrolls, whatever the bars above and the dock below cover.
                DockFold.Position(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    end: geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom - geometry.containerSize.height
                )
            } action: { _, position in
                foldDock(dockFold.update(position, isEditing: isDockEditing))
            }
            .onScrollPhaseChange { _, phase in dockFold.phase = "\(phase)" }
            .onChange(of: isDockEditing) { _, editing in
                if editing { foldDock(dockFold.unfold()) }
            }
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
            // The magnifier brings the field into sight from anywhere in the list.
            .onChange(of: isSearchOpen) { _, open in
                if open { withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { proxy.scrollTo(Self.listTop, anchor: .top) } }
            }
            .onChange(of: isSearchFocused) { closeSearchIfDone() }
            .onChange(of: viewModel.query) { closeSearchIfDone() }
        }
    }

    /// The list's first row, where the magnifier scrolls to.
    private static let listTop = "scripts.top"

    /// A free block of the list (no card behind it, no separator): the header, the idea card, the filters.
    private func blockRow<Content: View>(top: CGFloat, horizontal: CGFloat = Metrics.gutter, @ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: 0, trailing: horizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    // MARK: - Rows

    private func row(for script: Script, state: ScriptState) -> some View {
        let rowView = ScriptRow(
            script: script, state: state, line: line(of: script, state: state), takeCount: takes.count(for: script.id),
            topicColor: tagging.color(for: script), showsTrailing: !viewModel.isSelecting,
            isSelected: viewModel.isSelecting ? viewModel.selection.contains(script.id) : nil,
            onRecord: { actions.record(script) },
            onTakes: { presentation.selectedTab = .takes }
        )
        return Group {
            if viewModel.isSelecting {
                // The row picks the script (its mark is inside the card, not on its edge where the list's edit mode put it).
                let isSelected = viewModel.selection.contains(script.id)
                Button {
                    Haptics.selection()
                    viewModel.toggleSelection(of: script.id)
                } label: {
                    rowView.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            } else {
                // The row opens its page, whatever its state (a draft straight into writing); a recorded script's videos are its "×3 ›".
                NavigationLink(value: ScriptRoute(scriptID: script.id, startsEditing: state == .draft)) { rowView }
                    .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        // The system's swipe actions: Record in the record red, More in the system's grey (it opens the actions sheet). No full swipe:
        // a long swipe must never start a recording by itself. None while selecting.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !viewModel.isSelecting {
                Button { actions.record(script) } label: {
                    Label("Record", systemImage: "record.circle")
                }
                .tint(Palette.record)
                Button { viewModel.actionsTarget = script } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tint(.gray)
            }
        }
        // More (from the swipe): every action in a menu-like popover on this row. What opens something else waits until it is gone.
        .popover(
            isPresented: Binding(
                get: { viewModel.actionsTarget?.id == script.id },
                set: { if !$0 { viewModel.actionsTarget = nil } }
            ),
            arrowEdge: .top
        ) {
            ScriptActionsPopover(
                script: script, folders: library.folders, actions: actions,
                onShare: { viewModel.shareTarget = script },
                perform: { action in
                    pendingAction = action
                    viewModel.actionsTarget = nil
                }
            )
            .onDisappear(perform: runPendingAction)
        }
        .contextMenu {
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
                .foregroundStyle(group.state == .ready ? Palette.successText : Palette.inkHint)
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
                .foregroundStyle(Palette.inkHint)
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
        case .draft: String(localized: "Drafts · \(group.count) · In progress")
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
                    action: { viewModel.query = "" }, accessibilityPrefix: "scripts.empty"
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
    }

    /// What the More menu was asked to do, once its popover has gone.
    private func runPendingAction() {
        let action = pendingAction
        pendingAction = nil
        action?()
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
        ReadTime.seconds(for: script.text)
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
