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
    @Environment(ToastService.self) private var toast
    @Environment(NotificationService.self) private var notifications
    @Environment(TakeLibraryService.self) private var takes
    @Environment(\.dismiss) private var dismiss

    init(route: ScriptRoute, services: AppServices) {
        _viewModel = State(initialValue: ScriptDetailViewModel(
            scriptID: route.scriptID,
            startsEditing: route.startsEditing,
            writing: route.writing,
            ideaDraft: services.ideaDraft,
            revealPause: UIAccessibility.isReduceMotionEnabled ? .zero : services.scriptRevealPause,
            library: services.library,
            takes: services.takes,
            preferences: services.preferences,
            profile: services.profile,
            rules: services.rules,
            writer: services.writer,
            toast: services.toast,
            voiceQuestions: services.voiceQuestions,
            transition: services.ideaTransition
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if let script = viewModel.script {
                ScriptPageView(
                    viewModel: viewModel,
                    script: script,
                    folders: library.folders,
                    actions: actions,
                    onBack: { dismiss() },
                    onRecord: { presentation.openPrompter(scriptID: script.id, mode: .selfie) },
                    onOpenTake: { presentation.openReview(of: $0) }
                )
            } else {
                ContentUnavailableView("This script was deleted", systemImage: "doc.text")
            }
        }
        .background(Palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .hidesCueTabBar()
        .task { viewModel.beginWritingIfNeeded() }
        .onDisappear(perform: offerReminderInvite)
        .alert("Couldn't write the script", isPresented: Binding(
            get: { viewModel.page.writingError != nil },
            set: { if !$0 { viewModel.page.writingError = nil } }
        )) {
            Button("Try again") { viewModel.retryWriting() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.page.writingError ?? "")
        }
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
            case .reminder:
                if let script = viewModel.script {
                    ReminderSheet(subject: .script(script.id), title: script.displayTitle) { ReminderFeedback.show($0, toast: toast) }
                }
            }
        }
    }

    /// Leaving a finished script without recording it: the second invitation to allow notifications (only after a "Not now", 14 days on).
    private func offerReminderInvite() {
        guard let script = viewModel.script, script.isFinished, takes.takes(for: script.id).isEmpty else { return }
        let (notifications, presentation, hasRecorded) = (notifications, presentation, !takes.takes.isEmpty)
        Task {
            guard let reason = await notifications.invite(.readyScript, hasRecorded: hasRecorded),
                  presentation.sheet == nil, presentation.prompter == nil else { return }
            presentation.present(.notificationInvite(reason))
        }
    }

    private var actions: ScriptActions {
        ScriptActions(
            record: { presentation.openPrompter(scriptID: $0.id, mode: .selfie) },
            studio: { presentation.openPrompter(scriptID: $0.id, mode: .studio) },
            // The page is where the words are edited: its menu has no Edit.
            edit: { _ in },
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
