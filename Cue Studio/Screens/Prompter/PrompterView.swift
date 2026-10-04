//
//  PrompterView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Full-screen prompter session: Selfie or Studio mode, then the review of each take.
struct PrompterView: View {
    @State private var viewModel: PrompterViewModel
    /// Where the safe area ends, from the top of the screen: Display and camera sheets stop between
    /// the Selfie text window and here, so the script stays in sight.
    @State private var safeAreaBottom: CGFloat = 0
    /// The Takes tab's Share or Edit, taken once by the first review that opens.
    @State private var launchActionTaken = false
    private let services: AppServices

    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(CreatorProfileService.self) private var profile
    @Environment(DocumentImportService.self) private var importer
    @Environment(ToastService.self) private var toast
    @Environment(LanguageService.self) private var languages

    init(launch: PrompterLaunch, services: AppServices) {
        self.services = services
        _viewModel = State(initialValue: PrompterViewModel(
            launch: launch,
            library: services.library,
            takes: services.takes,
            preferences: services.preferences,
            profile: services.profile,
            rules: services.rules,
            camera: services.camera,
            audio: services.audio,
            microphones: services.audio,
            speech: services.speech,
            languages: services.languages,
            remote: services.remote,
            toast: services.toast
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            if let take = viewModel.reviewingTake {
                TakeReviewView(
                    takeID: take.id,
                    services: services,
                    onRetake: { Task { await viewModel.retake() } },
                    onBack: leaveReview,
                    onSelect: { viewModel.reviewingTake = $0 },
                    onDeleted: { next in
                        if let next {
                            viewModel.reviewingTake = next
                        } else {
                            leaveReview()
                        }
                    },
                    onOpenScript: { id in
                        presentation.closePrompter()
                        presentation.openScript(id)
                    },
                    launchAction: launchActionTaken ? nil : presentation.prompter?.reviewAction,
                    onLaunchActionDone: { launchActionTaken = true }
                )
                .id(take.id)
                .transition(.opacity)
            } else {
                switch viewModel.mode {
                case .selfie:
                    SelfieModeView(viewModel: viewModel, onClose: presentation.closePrompter, onPractice: finishPractice)
                case .studio:
                    StudioModeView(viewModel: viewModel, onClose: presentation.closePrompter)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { safeAreaBottom = $0 }
        .background(Color.black.ignoresSafeArea())
        .toastHost()
        .task {
            // Reading a long script must not let the screen sleep.
            UIApplication.shared.isIdleTimerDisabled = true
            await viewModel.appear()
            viewModel.startPractice()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await viewModel.disappear() }
        }
        // The session's camera: the Creator Setup, an accepted recommendation or a change for this take.
        .onChange(of: viewModel.session.camera) {
            Task { await viewModel.cameraSettingsChanged() }
        }
        .onChange(of: viewModel.session.prompter.scrollMode) {
            viewModel.scrollModeChanged()
        }
        .sheet(item: $viewModel.sheet) { sheet in
            sheetContent(sheet)
        }
        // After the sheets, so they read the same session.
        .environment(viewModel.session)
    }

    /// The practice run's end: the first flight is over, and the prompter either records for real or goes to the studio.
    private func finishPractice(_ outcome: PracticeOutcome) {
        services.onboarding.complete()
        switch outcome {
        case .recordForReal:
            viewModel.leavePractice()
        case .studio:
            presentation.closePrompter()
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: PrompterSheet) -> some View {
        switch sheet {
        case .display:
            DisplaySettingsSheet(viewModel: viewModel, maxHeight: sheetMaxHeight)
        case .destination:
            DestinationSheet(current: viewModel.script?.platform ?? profile.profile.defaultPlatform) { viewModel.setPlatform($0) }
        case .camera:
            CameraSettingsSheet(maxHeight: sheetMaxHeight)
        case .audioInput:
            AudioInputSheet()
        case .recordingSetup:
            RecordingSetupSheet(viewModel: viewModel)
        case .remote:
            RemoteControlSheet()
        case .addScript:
            StartRecordingSheet(
                mode: .attach,
                recent: Array(library.scripts.prefix(StartRecordingSheet.recentLimit)),
                readSeconds: { ReadTime.seconds(for: $0.text, speed: viewModel.session.prompter.speed) },
                onPick: { viewModel.attach($0) },
                onNewScript: { viewModel.sheet = .newScript }
            )
        case .newScript:
            NewScriptSheet(
                mode: .attach,
                onPaste: pasteAndAttach,
                onImport: { viewModel.sheet = .importScript }
            )
        case .importScript:
            ImportScriptSheet(
                onImported: { document in
                    let script = library.create(
                        title: document.title, text: document.text, platform: profile.profile.defaultPlatform,
                        language: languages.scriptLanguage
                    )
                    viewModel.attach(script)
                },
                onPaste: pasteAndAttach
            )
        }
    }

    /// Tallest a Selfie sheet may grow while the text window above it stays in sight.
    private var sheetMaxHeight: CGFloat? {
        viewModel.sheetCeiling.map { ScriptPanelClearance.sheetHeight(panelBottom: $0, safeAreaBottom: safeAreaBottom) }
    }

    /// Back from a take: to the Takes tab when the review was opened from there, otherwise to the
    /// camera for another take.
    private func leaveReview() {
        if viewModel.openedOnReview {
            presentation.closePrompter()
        } else {
            Task { await viewModel.retake() }
        }
    }

    private func pasteAndAttach() {
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
        viewModel.attach(script)
    }
}

#if DEBUG
#Preview {
    PrompterView(launch: PrompterLaunch(scriptID: SampleScripts.morningHabits.id, mode: .studio), services: .preview)
        .previewEnvironment()
}
#endif
