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
        let store = services.store
        _viewModel = State(initialValue: ScriptDetailViewModel(
            scriptID: route.scriptID,
            startsEditing: route.startsEditing,
            library: services.library,
            takes: services.takes,
            preferences: services.preferences,
            profile: services.profile,
            rules: services.rules,
            writer: services.writer,
            tier: { store.tier },
            toast: services.toast
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if let script = viewModel.script {
                if viewModel.isEditing {
                    ScriptEditorView(viewModel: viewModel, script: script)
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
                    onUnlock: viewModel.locksHookVariations ? { viewModel.unlockHookVariations() } : nil,
                    onPick: { viewModel.replaceHook(with: $0) },
                    onMore: { Task { await viewModel.showMoreHooks() } }
                )
                .fullScreenCover(item: paywallBinding(isActive: true)) { context in
                    PaywallView(context: context, onPurchased: { Task { await viewModel.showMoreHooks() } })
                }
            }
        }
        // A sheet covers this view, so the paywall opens from the sheet while one is up.
        .fullScreenCover(item: paywallBinding(isActive: viewModel.sheet == nil)) { PaywallView(context: $0) }
    }

    private func paywallBinding(isActive: Bool) -> Binding<PaywallContext?> {
        Binding(get: { isActive ? viewModel.paywall : nil }, set: { viewModel.paywall = $0 })
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.cancelEditing() }
                    .accessibilityIdentifier("editor.cancelButton")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    viewModel.finishEditing()
                } label: {
                    Text("Done").foregroundStyle(Palette.accInk)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.acc)
                .accessibilityIdentifier("editor.doneButton")
            }
        } else if let script = viewModel.script {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
                    .accessibilityIdentifier("detail.editButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
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
            versionsAreLocked: viewModel.locksPlatformVersions
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
