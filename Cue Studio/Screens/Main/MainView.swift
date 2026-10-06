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
    @Environment(VoiceQuestionScheduler.self) private var voiceQuestions
    @Environment(IdeaTransitionService.self) private var ideaTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var presentation = presentation
        tabs
            // While the idea's star is on screen the app dims and draws back behind it (0.6 s), as the board has it (09 §8).
            .scaleEffect(dimsForTransition && !reduceMotion ? 0.94 : 1, anchor: UnitPoint(x: 0.5, y: 0.4))
            .brightness(dimsForTransition ? -0.4 : 0)
            .saturation(dimsForTransition ? 0.7 : 1)
            .blur(radius: dimsForTransition ? 10 : 0)
            .animation(
                reduceMotion ? .easeOut(duration: 0.3) : .timingCurve(0.2, 0.8, 0.2, 1, duration: IdeaTransitionService.riseDuration * ideaTransition.speed),
                value: dimsForTransition
            )
            .overlay { StarTransitionOverlay(transition: ideaTransition).ignoresSafeArea() }
            .overlay(alignment: .bottom) { continuePostingCard }
            .sheet(item: $presentation.sheet) { sheet in
                sheetContent(sheet)
            }
            .fullScreenCover(item: $presentation.prompter) { launch in
                PrompterView(launch: launch, services: services)
            }
            .fullScreenCover(isPresented: $presentation.showsRemoteController) {
                RemoteControllerView()
            }
            // The My Cue Voice tip waits until the app has been opened on two different days.
            .task { voiceQuestions.registerAppOpen() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { voiceQuestions.registerAppOpen() }
            }
    }

    /// A "Share to universe" queue the creator left: on Scripts and Takes, 104 pt above the bottom, until it is continued or left for later.
    @ViewBuilder
    private var continuePostingCard: some View {
        let onList = (presentation.selectedTab == .scripts && presentation.scriptsPath.isEmpty) || presentation.selectedTab == .takes
        if onList, !presentation.hidesTabBar, let queue = services.shareQueue.pending {
            ContinuePostingCard(queue: queue) { continuePosting(queue) } onClose: { leaveForLater(queue) }
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func continuePosting(_ queue: ShareQueue) {
        guard let take = services.takes.take(id: queue.takeID) else {
            services.shareQueue.discard(takeID: queue.takeID)
            return
        }
        presentation.openReview(of: take, then: .continueQueue)
    }

    private func leaveForLater(_ queue: ShareQueue) {
        services.shareQueue.moveRestToLater(takeID: queue.takeID)
        toast.show(String(localized: "Saved · post when you’re ready"))
    }

    /// The star is rising or waiting: the app behind it is dimmed.
    private var dimsForTransition: Bool {
        ideaTransition.phase == .rising || ideaTransition.phase == .waiting
    }

    /// The system's tab bar (Liquid Glass on iOS 26+): content scrolls under it, the selection slides with a drag
    /// across it, and it steps out of the way when a screen asks (`hidesCueTabBar`). Record is not a destination:
    /// selecting it opens "Start recording" and the selection stays where it was.
    private var tabs: some View {
        @Bindable var presentation = presentation
        let barVisibility: Visibility = presentation.hidesTabBar ? .hidden : .automatic
        return TabView(selection: tabSelection) {
            Tab(value: AppTab.scripts) {
                NavigationStack(path: $presentation.scriptsPath) {
                    ScriptsView(library: services.library, toast: services.toast, writer: services.writer, drafts: services.drafts)
                        .navigationDestination(for: ScriptRoute.self) { route in
                            ScriptDetailView(route: route, services: services)
                        }
                }
                .toolbarVisibility(barVisibility, for: .tabBar)
            } label: {
                Label { Text("Scripts") } icon: { Image(uiImage: CueTabImage.template(.scripts)) }
            }
            Tab(value: AppTab.takes) {
                NavigationStack { TakesView(services: services) }
                    .toolbarVisibility(barVisibility, for: .tabBar)
            } label: {
                Label { Text("Takes") } icon: { Image(uiImage: CueTabImage.template(.takes)) }
            }
            Tab(value: AppTab.record) {
                Color.clear
            } label: {
                Label { Text("Record") } icon: { Image(uiImage: CueTabImage.record) }
            }
            Tab(value: AppTab.profile) {
                NavigationStack { ProfileView() }
                    .toolbarVisibility(barVisibility, for: .tabBar)
            } label: {
                Label { Text("Profile") } icon: { Image(uiImage: CueTabImage.template(.profile)) }
            }
            Tab(value: AppTab.settings) {
                NavigationStack(path: $presentation.settingsPath) { SettingsView() }
                .toolbarVisibility(barVisibility, for: .tabBar)
            } label: {
                Label { Text("Settings") } icon: { Image(uiImage: CueTabImage.template(.settings)) }
            }
        }
        .tint(Palette.accText)
        // The bar stays full while a list scrolls: the creator chose it over the design's `.onScrollDown` (07 §1), which
        // drew the bar back on every scroll down.
        .tabBarMinimizeBehavior(.never)
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
                onLetCue: { presentation.present(.ideas) },
                onWrite: writeNewScript,
                onImport: { presentation.present(.importScript) },
                onStartFromFormat: { presentation.present(.startFromFormat) },
                onAnswer: { presentation.present(.answerComment) },
                onFreestyle: {
                    presentation.sheet = nil
                    presentation.openPrompter(scriptID: nil, mode: .selfie)
                },
                hasAI: services.aiStatus.isAvailable
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
                        language: languages.scriptLanguage, isFinished: true
                    )
                    presentation.openScript(script.id)
                    toast.show(String(localized: "Imported \(document.kind.lowercased()) · \(document.wordCount) words"))
                }
            )
        case .ideas:
            IdeasSheet(
                services: services,
                onEdit: { idea in
                    services.ideaDraft.text = idea.prompt
                    services.ideaDraft.length = idea.length
                },
                onWrite: { idea in services.starter.write(idea: idea.prompt, length: idea.length) }
            )
        case .logbook:
            LogbookView()
                .presentationDetents([.large])
                .presentationCornerRadius(Metrics.editorSheetRadius)
        case .answerComment:
            AnswerCommentSheet(model: AnswerCommentViewModel(
                defaultPlatform: profile.profile.defaultPlatform, recognizer: services.textRecognizer,
                clipboard: { services.importer.clipboardText() },
                starter: { comment, platform in
                    presentation.sheet = nil
                    services.starter.write(idea: AnswerCommentViewModel.idea(for: comment), comment: comment, platform: platform)
                },
                writesByHand: { comment, _ in
                    presentation.sheet = nil
                    services.starter.writeByHand(idea: comment.text, comment: comment)
                },
                savesToLogbook: { text in
                    services.logbook.add(text)
                    toast.show(String(localized: "Saved to Logbook"))
                }
            ))
            .presentationDetents([.large])
        case .format:
            FormatSheet(mode: .card, current: services.ideaDraft.formatChoice) { choice in
                if choice.needsBrandBrief {
                    presentation.present(.brandBrief(.writeFromCard))
                } else {
                    services.ideaDraft.formatChoice = choice
                    presentation.sheet = nil
                }
            }
        case .startFromFormat:
            FormatSheet(mode: .blank, current: .talkingHead) { choice in
                if choice.needsBrandBrief {
                    presentation.present(.brandBrief(.draft))
                } else {
                    presentation.sheet = nil
                    services.starter.startFromFormat(choice)
                }
            }
        case .brandBrief(let purpose):
            BrandBriefSheet(store: services.brands, purpose: purpose, canWriteWithAI: services.aiStatus.isAvailable) { brief in
                presentation.sheet = nil
                switch purpose {
                case .writeFromCard where services.aiStatus.isAvailable:
                    // The ad is written from the brief and nothing else: the card's idea, or the product itself.
                    services.ideaDraft.formatChoice = .type(.ad)
                    services.ideaDraft.brand = brief
                    let idea = services.ideaDraft.submission ?? String(localized: "A sponsored ad for \(brief.product) by \(brief.name)")
                    services.starter.write(idea: idea)
                case .writeFromCard, .draft:
                    services.starter.startFromFormat(.type(.ad))
                }
            }
        case .createFor:
            DestinationSheet(current: services.starter.platform) {
                services.ideaDraft.platform = $0
                presentation.sheet = nil
            }
        }
    }

    private func writeNewScript() {
        let script = library.create(
            title: "", text: "", platform: profile.profile.defaultPlatform, language: languages.scriptLanguage, isFinished: false
        )
        presentation.openScript(script.id, editing: true)
    }
}

#if DEBUG
#Preview {
    MainView(services: .preview)
        .previewEnvironment()
}
#endif
