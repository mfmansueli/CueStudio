//
//  PrompterView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Full-screen prompter session: Selfie or Studio mode, then the review of each take.
struct PrompterView: View {
    @State private var viewModel: PrompterViewModel
    /// Where the Selfie script panel ends and the safe area ends, both from the top of the screen:
    /// the camera sheet stops between them so the script stays in sight.
    @State private var scriptPanelBottom: CGFloat?
    @State private var safeAreaBottom: CGFloat = 0
    private let services: AppServices

    @Environment(PreferencesService.self) private var preferences
    @Environment(PresentationService.self) private var presentation
    @Environment(ScriptLibraryService.self) private var library
    @Environment(CreatorProfileService.self) private var profile
    @Environment(DocumentImportService.self) private var importer
    @Environment(ToastService.self) private var toast

    init(launch: PrompterLaunch, services: AppServices) {
        self.services = services
        _viewModel = State(initialValue: PrompterViewModel(
            launch: launch,
            library: services.library,
            takes: services.takes,
            preferences: services.preferences,
            profile: services.profile,
            camera: services.camera,
            audio: services.audio,
            speech: services.speech,
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
                    onBack: {
                        if viewModel.openedOnReview {
                            presentation.closePrompter()
                        } else {
                            Task { await viewModel.retake() }
                        }
                    }
                )
                .id(take.id)
                .transition(.opacity)
            } else {
                switch viewModel.mode {
                case .selfie:
                    SelfieModeView(viewModel: viewModel, scriptPanelBottom: $scriptPanelBottom, onClose: presentation.closePrompter)
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
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await viewModel.disappear() }
        }
        .onChange(of: preferences.camera) {
            Task { await viewModel.cameraSettingsChanged() }
        }
        .onChange(of: preferences.prompter.scrollMode) {
            viewModel.scrollModeChanged()
        }
        .sheet(item: $viewModel.sheet) { sheet in
            sheetContent(sheet)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: PrompterSheet) -> some View {
        switch sheet {
        case .display:
            DisplaySettingsSheet(mode: viewModel.mode)
        case .camera:
            CameraSettingsSheet(maxHeight: scriptPanelBottom.map {
                ScriptPanelClearance.sheetHeight(panelBottom: $0, safeAreaBottom: safeAreaBottom)
            })
        case .addScript:
            NewScriptSheet(
                mode: .attach,
                recent: Array(library.scripts.prefix(3)),
                readSeconds: { ReadTime.seconds(for: $0.text, speed: preferences.prompter.speed) },
                onPaste: pasteAndAttach,
                onImport: { viewModel.sheet = .importScript },
                onGenerate: { viewModel.sheet = .generateScript },
                onPick: { viewModel.attach($0) }
            )
        case .importScript:
            ImportScriptSheet(
                onImported: { document in
                    let script = library.create(title: document.title, text: document.text, platform: profile.profile.defaultPlatform)
                    viewModel.attach(script)
                },
                onPaste: pasteAndAttach
            )
        case .generateScript:
            GenerateScriptSheet(services: services) { viewModel.attach($0) }
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
            platform: profile.profile.defaultPlatform
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
