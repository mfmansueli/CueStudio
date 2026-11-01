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
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast
    @Environment(LanguageService.self) private var languages
    @Environment(VoiceQuestionScheduler.self) private var voiceQuestions
    @Environment(IdeaTransitionService.self) private var ideaTransition
    @Environment(GuidanceGate.self) private var guidance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// The app as it was when an idea was sent, held still behind its star (`TransitionBackdrop`); the live app is hidden meanwhile.
    @State private var backdrop: UIView?
    /// Goes up each time Cancel or an error brings the live app back from behind the star: it comes back drawn back, and comes forward.
    @State private var liveAppReturns = 0

    var body: some View {
        @Bindable var presentation = presentation
        let forward = comingForward
        tabs
            // Back from behind the star (Cancel, an error): from as dark as the still was, the light comes back with the rise's curve
            // (09 §8). At its full size: shrunk, the screen showed square corners on black until it grew back (owner, 30/10/2026).
            .keyframeAnimator(initialValue: 0.0, trigger: liveAppReturns) { content, amount in
                content.modifier(TransitionDim(amount: amount, recedes: false))
            } keyframes: { _ in
                MoveKeyframe(1.0)
                LinearKeyframe(0.0, duration: forward.duration, timingCurve: forward.curve)
            }
            .opacity(backdrop == nil ? 1 : 0)
            .overlay {
                if let backdrop { TransitionBackdrop(still: backdrop) }
            }
            .overlay { StarTransitionOverlay(transition: ideaTransition).ignoresSafeArea() }
            .onChange(of: ideaTransition.showsBackdrop) { _, shows in
                if shows {
                    backdrop = TransitionBackdrop.takeStill()
                } else if backdrop != nil {
                    backdrop = nil
                    // The finish opens the ring onto the page under a solid cover; only an exit shows the live app coming forward.
                    if ideaTransition.phase == .leaving { liveAppReturns += 1 }
                }
            }
            .overlay(alignment: .bottom) { continuePostingCard }
            // The creator's queue left waiting has Scripts and Takes first: the tips wait while it is there (`GuidanceGate`).
            .onChange(of: services.shareQueue.pending?.takeID, initial: true) { _, takeID in
                for place in GuidancePlace.allCases {
                    if takeID != nil { guidance.shown(.continuePosting, at: place) } else { guidance.left(.continuePosting, at: place) }
                }
            }
            // The first voyage counts each step done (said in place, never as a toast).
            .background { VoyageProgressWatcher() }
            .sheet(item: $presentation.sheet) { sheet in
                sheetContent(sheet)
            }
            .fullScreenCover(item: $presentation.prompter) { launch in
                PrompterView(launch: launch, services: services)
            }
            .fullScreenCover(isPresented: $presentation.showsRemoteController) {
                RemoteControllerView()
            }
            .fullScreenCover(item: $presentation.paywall) { PaywallView(context: $0) }
            // Back from the teleprompter or the editor: a tool's introduction may fit now (one a session at most).
            .onChange(of: presentation.prompter == nil) { _, closed in
                if closed { offerIntroduction() }
            }
            // The My Cue Voice tip waits until the app has been opened on two different days.
            .task { voiceQuestions.registerAppOpen() }
            // The patterns' engine is made off the main thread now, not by the first one played (the first idea's takeoff).
            .task { HapticPatterns.prewarm() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    guidance.appBecameActive()
                    voiceQuestions.registerAppOpen()
                case .background: guidance.appLeftScreen()
                default: break
                }
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
        // Closed by the creator: nothing else takes its place on this screen this session.
        let place: GuidancePlace = presentation.selectedTab == .takes ? .takes : .scripts
        guidance.left(.continuePosting, at: place, closed: true)
        services.shareQueue.moveRestToLater(takeID: queue.takeID)
        toast.show(String(localized: "Saved · post when you’re ready"))
    }

    /// The live app coming forward again after an exit: the rise's curve and length (Reduce Motion: 0.3 s, eased out).
    private var comingForward: (duration: TimeInterval, curve: UnitCurve) {
        if reduceMotion { return (0.3 * ideaTransition.speed, .easeOut) }
        let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8), endControlPoint: UnitPoint(x: 0.2, y: 1))
        return (IdeaTransitionService.riseDuration * ideaTransition.speed, curve)
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
                    ScriptsView(
                        library: services.library, toast: services.toast, logbook: services.logbook, writer: services.writer,
                        drafts: services.drafts, defaults: services.defaults
                    )
                        // On the list (its selection hides the bar), not on the stack: the script page pushed over it hides the bar
                        // itself, the system's way, which a stack-wide setting would override.
                        .toolbarVisibility(barVisibility, for: .tabBar)
                        .navigationDestination(for: ScriptRoute.self) { route in
                            ScriptDetailView(route: route, services: services)
                        }
                }
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
                NavigationStack(path: $presentation.profilePath) {
                    ProfileView()
                        .navigationDestination(for: ProfileRoute.self) { route in
                            YourUniverseView(opensYearInReview: route == .yearInReview)
                        }
                }
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

    /// The sponsored ad's draft, in the dock idea's language when that is known: what Apple Intelligence can't draft in opens the draft to
    /// write instead.
    private var adDrafting: DraftingAvailability { services.starter.drafting(before: services.ideaDraft.submission) }

    private var canDraftAd: Bool { services.aiStatus.isAvailable && adDrafting.isAvailable }

    /// A brand brief filled in: the card's ad is written from it (by hand, for the card's platform, without Apple Intelligence); "Draft" opens
    /// the ad's sections to write.
    private func writeAd(from brief: BrandBrief, for purpose: BrandBriefPurpose) {
        switch purpose {
        case .writeFromCard where canDraftAd:
            // The ad is written from the brief and nothing else: the card's idea, or the product itself.
            services.ideaDraft.formatChoice = .type(.ad)
            services.ideaDraft.brand = brief
            let idea = services.ideaDraft.submission ?? String(localized: "A sponsored ad for \(brief.product) by \(brief.name)")
            services.starter.write(idea: idea, fromDock: true)
        case .writeFromCard:
            services.starter.startFromFormat(.type(.ad), platform: services.starter.platform)
        case .draft:
            services.starter.startFromFormat(.type(.ad))
        }
    }

    /// Why the ad opens as a draft to write, when the language is the reason (without Apple Intelligence the sheet simply has no AI).
    private var adDraftingNotice: String? {
        guard let cause = adDrafting.cause, cause.isLanguage else { return nil }
        return cause.reason + " " + String(localized: "Open the draft to write it yourself.")
    }

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
                // A Script Language Apple Intelligence can't draft in is the same as no Apple Intelligence here.
                hasAI: services.aiStatus.isAvailable && services.starter.dockDrafting.isAvailable
            )
        case .startRecording:
            StartRecordingSheet(
                mode: .new,
                recent: Array(library.scripts.prefix(StartRecordingSheet.recentLimit)),
                readSeconds: { $0.readSeconds },
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
            FindInspirationSheet(services: services)
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
                },
                drafting: { services.starter.drafting(before: $0) }
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
            BrandBriefSheet(
                store: services.brands, purpose: purpose, canWriteWithAI: canDraftAd,
                notice: purpose == .writeFromCard ? adDraftingNotice : nil
            ) { brief in
                presentation.sheet = nil
                writeAd(from: brief, for: purpose)
            }
        case .createFor:
            DestinationSheet(current: services.starter.platform) {
                services.ideaDraft.platform = $0
                presentation.sheet = nil
            }
        case .ultraConsent:
            UltraConsentSheet {
                services.ultra.consent.grant()
                services.starter.choose(.ultra)
            }
        case .featureIntro, .voiceSetup, .importWriting, .notificationInvite:
            notificationSheet(sheet)
        }
    }

    /// What a notification opens as a sheet: a tool's introduction, My Cue Voice's questions, Import my writing.
    @ViewBuilder
    private func notificationSheet(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .featureIntro(let request): featureIntro(request)
        case .voiceSetup: VoiceSetupSheet(mode: .missing, profile: profile.profile)
        case .importWriting: WritingImportSheet()
        case .notificationInvite(let reason, let scriptID): notificationInvite(reason, scriptID: scriptID)
        default: EmptyView()
        }
    }

    // MARK: - Introductions

    /// "Try it" opens the tool on the creator's own script or take; "Not now" waits 30 days; "Don't suggest this" is for good.
    private func featureIntro(_ request: FeatureIntroRequest) -> some View {
        let notifications = services.notifications
        return FeatureIntroSheet(
            request: request,
            onTry: {
                notifications.introAccepted(request)
                Task { await NotificationNavigator(services: services).go(to: request.destination) }
            },
            onNotNow: {
                notifications.introSnoozed(request)
                presentation.sheet = nil
            },
            onDecline: {
                notifications.introDeclined(request)
                presentation.sheet = nil
            },
            // Swiped away: the same as "Not now".
            onDismissed: { notifications.introSnoozed(request) }
        )
        .onAppear { notifications.introShown(request) }
    }

    /// One thing at a quiet moment after a session at the camera or the editor (`GuidanceGate`): never after a celebration in this session.
    /// The invitation to allow notifications comes only in a session after the first recording's, while a video is still to finish (owner,
    /// 30/10/2026); else a tool's introduction. Each is looked at again just before it shows.
    private func offerIntroduction() {
        Task {
            let notifications = services.notifications
            let takes = services.takes.takes
            let firstTake = takes.map(\.recordedAt).min()
            let shared = services.milestones.sharedTakeIDs
            let unfinished = takes.contains { !shared.contains($0.id) }
            if guidance.mayAsk(firstTakeAt: firstTake),
               let reason = await notifications.invite(.firstRecording, hasRecorded: unfinished) {
                guard presentation.sheet == nil, presentation.prompter == nil, guidance.mayAsk(firstTakeAt: firstTake) else { return }
                presentation.present(.notificationInvite(reason, scriptID: nil))
                return
            }
            guard guidance.mayAsk(firstTakeAt: nil), let request = await notifications.inAppIntro(afterSession: true),
                  presentation.sheet == nil, presentation.prompter == nil, guidance.mayAsk(firstTakeAt: nil) else { return }
            presentation.present(.featureIntro(request))
        }
    }

    /// "Allow notifications" brings up the system's question; "Not now" keeps it for later. For a script left without a take, the button
    /// says what it does ("Remind me tomorrow"): the system's question, then the reminder for that script.
    private func notificationInvite(_ reason: NotificationInviteReason, scriptID: UUID?) -> some View {
        let notifications = services.notifications
        let (toast, library) = (toast, library)
        return NotificationInviteSheet(
            reason: reason,
            onAllow: {
                presentation.sheet = nil
                Task {
                    await notifications.inviteAccepted(reason)
                    guard reason == .readyScript, let scriptID, let script = library.script(id: scriptID),
                          let time = ReminderChoice.tomorrow.time(now: .now, calendar: .current) else { return }
                    // Kept in Cue even if iOS said no; the toast says which.
                    let result = await notifications.setReminder(.script(scriptID), title: script.displayTitle, at: time)
                    ReminderFeedback.show(result, toast: toast)
                }
            },
            onNotNow: {
                notifications.inviteDeclined(reason)
                presentation.sheet = nil
            },
            onDismissed: { notifications.inviteDeclined(reason) }
        )
        .onAppear { notifications.inviteShown(reason) }
    }

    private func writeNewScript() {
        services.starter.newBlank(platform: profile.profile.defaultPlatform)
    }
}

#if DEBUG
#Preview {
    MainView(services: .preview)
        .previewEnvironment()
}
#endif
