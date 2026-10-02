//
//  ScriptDetailView.swift
//  Cue Studio
//

import SwiftUI

struct ScriptDetailView: View {
    @State private var viewModel: ScriptDetailViewModel

    @Environment(ScriptLibraryService.self) private var library
    @Environment(PresentationService.self) private var presentation
    @Environment(PreferencesService.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    init(route: ScriptRoute, services: AppServices) {
        _viewModel = State(initialValue: ScriptDetailViewModel(
            scriptID: route.scriptID,
            startsEditing: route.startsEditing,
            library: services.library,
            takes: services.takes,
            preferences: services.preferences,
            profile: services.profile,
            rules: services.rules,
            writer: services.writer,
            toast: services.toast
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if let script = viewModel.script {
                if viewModel.isEditing {
                    ScriptEditorView(viewModel: viewModel)
                } else {
                    ScriptReadView(
                        viewModel: viewModel,
                        script: script,
                        onStudio: { presentation.openPrompter(scriptID: script.id, mode: .studio) },
                        onRecord: { presentation.openPrompter(scriptID: script.id, mode: .selfie) },
                        onOpenTake: { presentation.openReview(of: $0) }
                    )
                }
            } else {
                ContentUnavailableView("This script was deleted", systemImage: "doc.text")
            }
        }
        .background(Palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isEditing)
        // Writing has its own header (the title, the length and Done), so nothing sits above it.
        .toolbarVisibility(viewModel.isEditing ? .hidden : .automatic, for: .navigationBar)
        .toolbar { toolbarContent }
        .toolbarVisibility(.hidden, for: .tabBar)
        .alert("New folder", isPresented: $viewModel.isNamingFolder) {
            TextField("Folder name", text: $viewModel.newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { viewModel.confirmNewFolder() }
        }
        .sheet(item: $viewModel.sheet) { sheet in
            switch sheet {
            case .destination:
                DestinationSheet(current: viewModel.script?.platform ?? .tiktok) { viewModel.setPlatform($0) }
            case .hooks:
                HooksSheet(
                    currentHook: viewModel.currentHook,
                    options: viewModel.hookOptions,
                    speed: preferences.prompter.speed,
                    isLoading: viewModel.isLoadingHooks,
                    onPick: { viewModel.replaceHook(with: $0) },
                    onMore: { Task { await viewModel.showMoreHooks() } }
                )
            case .improve:
                ImproveScriptSheet(viewModel: viewModel)
            case .details:
                ScriptDetailsSheet(viewModel: viewModel)
            case .scriptType:
                ScriptTypeSheet(current: viewModel.script?.type) { viewModel.setType($0) }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !viewModel.isEditing, let script = viewModel.script {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
                    .accessibilityIdentifier("detail.editButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Script details", systemImage: "info.circle") { viewModel.sheet = .details }
                    ScriptActionsMenu(script: script, folders: library.folders, actions: actions)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }

    private var actions: ScriptActions {
        ScriptActions(
            record: { presentation.openPrompter(scriptID: $0.id, mode: .selfie) },
            studio: { presentation.openPrompter(scriptID: $0.id, mode: .studio) },
            edit: { _ in viewModel.startEditing() },
            duplicate: { _ in viewModel.duplicate() },
            move: { viewModel.move(to: $1) },
            moveToNewFolder: { _ in viewModel.startNewFolder() },
            delete: { _ in
                viewModel.delete()
                dismiss()
            },
            makeVersion: { _, platform in Task { await viewModel.makeVersion(for: platform) } },
            setLanguage: { _, language in viewModel.setLanguage(language) }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ScriptDetailView(route: ScriptRoute(scriptID: SampleScripts.morningHabits.id), services: .preview)
    }
    .previewEnvironment()
}
#endif
