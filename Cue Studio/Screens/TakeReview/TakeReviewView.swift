//
//  TakeReviewView.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI

/// Watch the take (it opens paused), compare it with the video's other takes (swipe), mark the best
/// one, then continue the edit, retake, save or share. The card under the video says where the
/// video is on its way out.
struct TakeReviewView: View {
    @State private var viewModel: TakeReviewViewModel
    let onRetake: () -> Void
    let onBack: () -> Void
    /// Another take of the same script, from the strip.
    let onSelect: (Take) -> Void
    /// After deleting: the take to show next, or nil to leave the review.
    let onDeleted: (Take?) -> Void
    /// "From script ›": leaves the review for the script this take was read from.
    let onOpenScript: (UUID) -> Void
    /// Share or Edit asked for by the Takes tab as it opened this review; `onLaunchActionDone` tells
    /// the caller it has been taken, so another take of the video doesn't repeat it.
    var launchAction: ReviewLaunchAction?
    var onLaunchActionDone: () -> Void = {}
    /// Reached by a swipe from another take of the video: "Take 2 of 3" shows for a moment.
    var arrivedFromNeighbor = false

    @State private var flow: ShareFlow
    @State private var playback = ReviewPlayback()
    /// The screen is recorded or mirrored: the video carries Cue's mark on the free plan (`CaptureWatermark`).
    @SceneCaptured private var isSceneCaptured

    /// "Pick your best take", opened by ✦ Suggest best.
    @State private var proposal: BestTakeProposal?
    @State private var editingTake: Take?
    /// The tool the editor opens on (a notification's "Try it"), for the next time it opens.
    @State private var editingTool: EditorTool?
    /// How the editor was left, acted on once its cover is gone (share, download, ready later).
    @State private var pendingOutcome: EditorOutcome?
    /// Share glows for a few seconds after "Ready, I'll post later".
    @State private var glowsShare = false
    /// Counts the times the editor was left, so the card redraws: an edit left open (a draft) isn't
    /// observable, but it decides "Continue" and the stage.
    @State private var editorVisits = 0
    private let services: AppServices
    @Environment(TakeEditService.self) private var editing
    @Environment(PersonalizationService.self) private var personalization
    @Environment(MilestoneService.self) private var milestones
    @Environment(AppIconService.self) private var appIcon
    @Environment(StoreManager.self) private var store
    @Environment(PresentationService.self) private var presentation
    /// The milestone a share just reached, told once the send-off is done.
    @State private var reachedMilestone: Int?
    @State private var tellsMilestone = false
    /// The first take ever: its star, told once.
    @State private var tellsFirstStar = false
    /// Pauses by a tap on the video: the pause sign blinks at each (`ReviewPauseFlash`).
    @State private var pauseFlashes = 0
    /// Times the take was made the best here: the star's sparks.
    @State private var bestBursts = 0
    /// Save's ✓, for a moment once the video is in Photos (after "Ready to travel" closes, so it is seen).
    @State private var justSaved = false
    /// Back or another take, asked for while the video exports: it waits for "Cancel export?".
    @State private var exitDuringExport: ReviewExit?
    /// Save or Share, asked for with an edit left open: it waits for "Keep editing" or the finished video's export.
    @State private var exportPastUnfinishedEdit: ReviewExport?
    /// Save or Share, asked for while files the edit names are gone: it waits for "Open editor" or "Remove and export".
    @State private var exportPastMissingMedia: ReviewExport?
    @State private var awaitsSavedCheck = false
    /// "Take 2 of 3" under the bar, after a swipe.
    @State private var showsPlace = false

    init(
        takeID: UUID, services: AppServices,
        onRetake: @escaping () -> Void, onBack: @escaping () -> Void,
        onSelect: @escaping (Take) -> Void, onDeleted: @escaping (Take?) -> Void,
        onOpenScript: @escaping (UUID) -> Void = { _ in },
        launchAction: ReviewLaunchAction? = nil, onLaunchActionDone: @escaping () -> Void = {}, arrivedFromNeighbor: Bool = false
    ) {
        let store = services.store
        let languages = services.languages
        let model = TakeReviewViewModel(
            takeID: takeID,
            takes: services.takes,
            quota: services.quota,
            tier: { store.tier },
            exporter: services.reviewExporter,
            photos: services.photos,
            sharing: services.sharing,
            ledger: services.ledger,
            editing: services.editing,
            library: services.library,
            rules: services.rules,
            profile: services.profile,
            preferences: services.preferences,
            drafts: services.drafts,
            toast: services.toast,
            background: services.backgroundExports,
            speechLanguage: { languages.captionRequest(for: $0) },
            likelySpokenLanguages: { languages.likelySpokenLanguages(for: $0) }
        )
        let notifications = services.notifications
        model.onExported = { takeID, saved in Task { await notifications.exportFinished(takeID: takeID, savedToPhotos: saved) } }
        _viewModel = State(initialValue: model)
        _flow = State(initialValue: ShareFlow(
            review: model, queues: services.shareQueue, milestones: services.milestones, library: services.library,
            defaults: services.defaults, toast: services.toast
        ))
        self.services = services
        self.onRetake = onRetake
        self.onBack = onBack
        self.onSelect = onSelect
        self.onDeleted = onDeleted
        self.onOpenScript = onOpenScript
        self.launchAction = launchAction
        self.onLaunchActionDone = onLaunchActionDone
        self.arrivedFromNeighbor = arrivedFromNeighbor
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        // A navigation stack of its own: the top controls are the system's bar, in its Liquid Glass, over the video.
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let take = viewModel.take {
                    video(for: take)
                    chrome(for: take)
                        // Here, not on the stack: one alert per view, and this one can follow "Unfinished edit".
                        .alert(
                            "Missing media",
                            isPresented: Binding(get: { exportPastMissingMedia != nil }, set: { if !$0 { exportPastMissingMedia = nil } }),
                            presenting: exportPastMissingMedia
                        ) { request in
                            Button("Open editor") { editingTake = viewModel.take }
                            if viewModel.canRemoveMissingMedia {
                                Button("Remove and export") { if viewModel.removeMissingMedia() { perform(request) } }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: { _ in
                            if viewModel.canRemoveMissingMedia {
                                Text("Some photos, videos or sounds in this edit are no longer on this iPhone. Fix them in the editor, or remove them and export.")
                            } else {
                                Text("A clip in this edit is no longer on this iPhone. Replace it in the editor to export.")
                            }
                        }
                } else {
                    ContentUnavailableView("This take was deleted", systemImage: "film")
                }
            }
            .overlay(alignment: .top) {
                if showsPlace, let take = viewModel.take {
                    placeChip(for: take)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .overlay(alignment: .top) {
                VoyageInPlaceTip(step: .pick, place: .review, isAllowed: showsPickTip) { isDone in
                    pickTip(isDone: isDone)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
            }
            // On the stack, not beside "Cancel export?": one alert per view.
            .alert(
                "Unfinished edit",
                isPresented: Binding(get: { exportPastUnfinishedEdit != nil }, set: { if !$0 { exportPastUnfinishedEdit = nil } }),
                presenting: exportPastUnfinishedEdit
            ) { request in
                Button("Keep editing") { editingTake = viewModel.take }
                if viewModel.hasFinishedEdit {
                    Button("Export last finished version") { run(request) }
                } else {
                    Button("Export original") { run(request) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                if viewModel.hasFinishedEdit {
                    Text("There are unfinished changes. You can keep editing or export the last finished version.")
                } else {
                    Text("There are unfinished changes. You can keep editing or export the original video.")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                if let take = viewModel.take {
                    toolbar(for: take)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let queue = services.shareQueue.pending, queue.takeID == viewModel.takeID, viewModel.celebration == nil {
                ContinuePostingCard(queue: queue) { continueQueue(nil) } onClose: {
                    services.shareQueue.moveRestToLater(takeID: queue.takeID)
                    services.toast.show(String(localized: "Saved · post when you’re ready"))
                }
                .padding(.bottom, 104)
            }
        }
        // A video player's controls: they stop growing at a large text size, or the actions land on
        // top of each other and the stage names turn into "ESC…".
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .alert(
            "Cancel export?",
            isPresented: Binding(get: { exitDuringExport != nil }, set: { if !$0 { exitDuringExport = nil } }),
            presenting: exitDuringExport
        ) { exit in
            Button("Cancel export", role: .destructive) {
                // False when the file got on its way meanwhile: it ends as it would have, and the review shows it.
                if viewModel.cancelExport() { follow(exit) }
            }
            Button("Keep exporting", role: .cancel) {}
        } message: { _ in
            Text("The video won't be saved or shared.")
        }
        // The export ended while the question was open: what it did shows (saved, the share sheet), never a "cancelled".
        .onChange(of: viewModel.runningAction == nil) { _, ended in
            if ended { exitDuringExport = nil }
        }
        .task(id: PlayerKey(takeID: viewModel.takeID, edit: viewModel.take?.edit)) { await runPlayer() }
        .onChange(of: viewModel.take?.edit?.showsCaptions ?? false) { _, shown in
            viewModel.burnsInCaptions = shown
        }
        .fullScreenCover(item: $editingTake, onDismiss: handleEditorOutcome) { take in
            QuickEditView(take: take, services: services, opening: editingTool) { outcome in
                pendingOutcome = outcome
                editingTool = nil
                editingTake = nil
            }
        }
        .fullScreenCover(item: $proposal) { proposal in
            PickBestTakeView(
                proposal: proposal,
                onUse: { chosen in
                    viewModel.markBest(chosen)
                    self.proposal = nil
                    if chosen.id != viewModel.takeID { onSelect(chosen) }
                },
                onRecordAgain: {
                    self.proposal = nil
                    onRetake()
                },
                onOpen: { opened in
                    self.proposal = nil
                    if opened.id != viewModel.takeID { onSelect(opened) }
                },
                onClose: { self.proposal = nil }
            )
        }
        .fullScreenCover(item: $viewModel.celebration) { celebration in
            celebrationView(celebration)
                // What is said while it is up ("Shared with TikTok", a failure) shows in front of it, not under it.
                .toastHost(inSheet: true)
        }
        .onChange(of: viewModel.celebration) { _, new in
            guard case .sentOff? = new else { return }
            // The networks the creator confirmed were counted as they were confirmed (`ShareFlow`); the milestone they reached is told after,
            // once: sharing the same take again in this review doesn't bring the same story back.
            reachedMilestone = flow.takeReachedMilestone()
            if !personalization.celebrations { viewModel.celebration = nil }
        }
        .storyCover(isPresented: $tellsFirstStar) {
            if let take = viewModel.take {
                FirstStarView(
                    take: take,
                    onStudio: { finishFirstStar() },
                    onEdit: { finishFirstStar(thenEdit: take) }
                )
            }
        }
        .storyCover(isPresented: $tellsMilestone) {
            if let reached = reachedMilestone, let icon = AppIconChoice(milestone: reached) {
                MilestoneView(
                    milestone: reached, icon: icon, isAvailable: !icon.needsPro || store.tier.isPro,
                    onUse: { useMilestoneIcon(icon, reached: reached) },
                    onKeep: { finishMilestone(reached) }
                )
            }
        }
        .onAppear {
            // A review opened to do something (edit, pick, share) does it first: a celebration never covers an opening action, and comes
            // at the end of that task instead (`GuidanceGate`).
            let opensTask = launchAction != nil
            presentation.reviewOnScreen = viewModel.takeID
            connectFlow()
            applyLaunchAction()
            if !opensTask { considerFirstStar() }
            showStoriesForTests()
            announcePlace()
        }
        .onChange(of: viewModel.savesToPhotos) { _, _ in
            awaitsSavedCheck = true
            showSavedCheck()
        }
        .onChange(of: viewModel.celebration == nil) { _, _ in showSavedCheck() }
        .onDisappear {
            playback.pause()
            viewModel.leave()
            if presentation.reviewOnScreen == viewModel.takeID { presentation.reviewOnScreen = nil }
        }
        .modifier(ExportPresentations(viewModel: viewModel, isActive: viewModel.celebration == nil))
    }

    // MARK: - Video

    private func video(for take: Take) -> some View {
        GeometryReader { proxy in
            let frame = frameSize(for: take.outputAspect, in: proxy.size)
            PlayerView(player: playback.player)
                .frame(width: frame.width, height: frame.height)
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.75), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        // Signed on the free plan while the screen is recorded or mirrored (`CaptureWatermark`); it plays as always.
        .captureWatermarked(isSceneCaptured)
        .contentShape(Rectangle())
        .onTapGesture { tapVideo() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { drag in
                // A clear horizontal swipe goes to the next (left) or the previous (right) take.
                guard abs(drag.translation.width) > 60, abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                leave(.neighbor(drag.translation.width < 0 ? 1 : -1))
            }
        )
    }

    /// Play, while the take is paused: in the middle of the video's free space, above the controls (centred on the whole screen, it sat on
    /// the playhead of a shorter iPhone, like the 15 Pro). Played, it shrinks away; a tap on the video that pauses blinks the pause sign
    /// there (`ReviewPauseFlash`).
    private var playButton: some View {
        ZStack {
            ReviewPauseFlash(trigger: pauseFlashes)
            if !playback.isPlaying {
                Button {
                    Haptics.light()
                    playback.play()
                } label: {
                    Image(systemName: "play.fill").offset(x: 2)
                }
                .buttonStyle(.cueIcon(.glass, diameter: 64))
                .accessibilityLabel(Text("Play"))
                .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: playback.isPlaying)
    }

    /// A tap on the video plays it, or pauses it and blinks the pause sign.
    private func tapVideo() {
        if playback.isPlaying {
            playback.pause()
            Haptics.soft()
            pauseFlashes += 1
        } else {
            Haptics.light()
            playback.play()
        }
    }

    /// "Take 2 of 3", for a moment after a swipe.
    private func placeChip(for take: Take) -> some View {
        let siblings = viewModel.siblings
        let index = (siblings.firstIndex { $0.id == take.id } ?? 0) + 1
        return Text("Take \(index) of \(siblings.count)")
            .cueFont(.footnote, weight: .semibold)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            .allowsHitTesting(false)
    }

    /// Portrait takes fill the screen; other frames are shown at their crop, letterboxed.
    private func frameSize(for aspect: AspectRatio, in size: CGSize) -> CGSize {
        guard aspect != .portrait else { return size }
        let height = size.width / aspect.widthOverHeight
        return CGSize(width: size.width, height: min(size.height, height))
    }

    // MARK: - Chrome

    private func toolbar(for take: Take) -> ReviewToolbar {
        ReviewToolbar(
            take: take,
            placeLabel: placeLabel(for: take),
            onBack: { leave(.back) },
            onToggleBest: {
                if !take.isBest {
                    HapticPatterns.playBestTake()
                    bestBursts += 1
                }
                viewModel.toggleBest()
            },
            // Gone at once, with 4 s of Undo in the toast (04 · F4): no question first.
            onDelete: {
                playback.pause()
                onDeleted(viewModel.delete())
            },
            onPrevious: viewModel.neighbor(-1) == nil ? nil : { leave(.neighbor(-1)) },
            onNext: viewModel.neighbor(1) == nil ? nil : { leave(.neighbor(1)) },
            onSuggest: viewModel.offersBestSuggestion && viewModel.runningAction == nil ? { suggestBest() } : nil,
            bestBursts: bestBursts,
            isExporting: viewModel.runningAction != nil
        )
    }

    private func chrome(for take: Take) -> some View {
        _ = editorVisits
        return VStack(spacing: 0) {
            // The free space above the controls (clear, so a tap still reaches the video): Play sits in its middle.
            Color.clear
                .frame(minHeight: 80)
                .overlay { playButton }
            VStack(alignment: .leading, spacing: 0) {
                ReviewScrubber(progress: playback.progress, duration: take.duration) { playback.seek(to: $0, of: take.duration) }
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5).padding(.top, 14)
                ReviewInfoPanel(
                    take: take, stage: viewModel.stage, lengthFit: viewModel.lengthFit, scriptVersion: viewModel.scriptVersionLabel,
                    dotColor: themeColor(of: take)
                )
                    .padding(.top, 20)
                ReviewActionBar(
                    runningAction: viewModel.runningAction,
                    glowsShare: glowsShare,
                    justSaved: justSaved,
                    editTitle: viewModel.hasOpenEdit ? String(localized: "Continue") : String(localized: "Edit"),
                    onEdit: {
                        playback.pause()
                        editingTake = take
                    },
                    // An imported video wasn't recorded here: nothing to record again.
                    onRetake: take.isImported ? nil : onRetake,
                    onSave: { export(.save) },
                    onScript: take.scriptID.map { id in { playback.pause(); onOpenScript(id) } },
                    onShare: { export(.share) }
                )
                .padding(.top, 22)
                if let progress = viewModel.exportProgress {
                    ExportProgressCard(progress: progress, mode: viewModel.exportMode).padding(.top, 10)
                } else if let failure = viewModel.exportFailure {
                    ExportFailedCard(
                        failure: failure, onRetry: { Task { await viewModel.retryFailedExport() } }, onClose: viewModel.dismissExportFailure
                    )
                    .padding(.top, 10)
                } else if viewModel.exportStopped {
                    ExportStoppedCard(onSave: { export(.save) }, onClose: viewModel.dismissStoppedExport).padding(.top, 10)
                }
                if viewModel.photosDenied {
                    PhotosDeniedCard { viewModel.photosDenied = false }.padding(.top, 10)
                }
                ReviewExportFooter(
                    label: viewModel.exportLabel, showsGoPro: viewModel.exportsLeft != nil,
                    later: services.shareQueue.later(forTake: viewModel.takeID).first?.network, onLater: { continueQueue(nil) },
                    left: viewModel.exportsLeft,
                    // The calm Pro is for when the free exports are gone; with some left it is just browsing.
                    onGoPro: { viewModel.paywall = viewModel.exportsExhausted ? .export : .profile }
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 6)
        }
    }

    /// The colour of the take's theme (the dot before its title), amber without one.
    private func themeColor(of take: Take) -> Color {
        let topic = services.library.scripts.first { $0.id == take.scriptID }?.topic
        guard let topic, let index = universeTopics.firstIndex(where: { $0.id == topic }) else { return Palette.World.warm }
        return OnboardingTopic.color(at: index)
    }

    /// "TAKE 2 OF 3", or "TAKE 1" for a video of one take.
    private func placeLabel(for take: Take) -> String {
        let siblings = viewModel.siblings
        guard siblings.count > 1, let index = siblings.firstIndex(where: { $0.id == take.id }) else { return String(localized: "TAKE \(take.number)") }
        return String(localized: "TAKE \(index + 1) OF \(siblings.count)")
    }

    // MARK: - Takes

    /// Swipe or the chip: another take of the same video, paused.
    /// Save or Share. With an edit left open that would change the video, "Unfinished edit" asks first: they export the finished video
    /// (or the recording, when no edit was ever finished), never the draft.
    private func export(_ request: ReviewExport) {
        guard viewModel.hasUnfinishedEdit else { return run(request) }
        playback.pause()
        exportPastUnfinishedEdit = request
    }

    /// The export asked for, once nothing it names is gone: "Missing media" asks first, never a black stretch nobody chose.
    private func run(_ request: ReviewExport) {
        guard viewModel.missingMedia.isEmpty else {
            playback.pause()
            exportPastMissingMedia = request
            return
        }
        perform(request)
    }

    private func perform(_ request: ReviewExport) {
        switch request {
        case .save: Task { await viewModel.save() }
        case .share: shareToUniverse()
        }
    }

    /// A way out of the review (Back, another take). While the video exports, "Cancel export?" asks first; once the file is on its way
    /// (`isDelivering`) it can't be called back, so nothing is asked and the way out waits: it ends in a moment, and says so. Leaving Cue
    /// is not a way out: the export goes on.
    private func leave(_ exit: ReviewExit) {
        guard viewModel.runningAction != nil else { return follow(exit) }
        guard viewModel.canCancelExport else { return }
        exitDuringExport = exit
    }

    private func follow(_ exit: ReviewExit) {
        switch exit {
        case .back: onBack()
        case .neighbor(let offset): selectNeighbor(offset)
        }
    }

    private func selectNeighbor(_ offset: Int) {
        guard let next = viewModel.neighbor(offset) else { return }
        Haptics.selection()
        playback.pause()
        onSelect(next)
    }

    /// The editor's Done question, answered: share opens "Share to", download saves to Photos (and
    /// counts as an export), ready later makes Share glow, and not yet or back change nothing here.
    private func handleEditorOutcome() {
        editorVisits += 1
        guard let outcome = pendingOutcome else {
            considerFirstStar()
            return
        }
        pendingOutcome = nil
        // The edit is the task that was opened: its end is the first star's moment (not when the next task, sharing, starts).
        if outcome != .share { considerFirstStar() }
        switch outcome {
        case .share:
            shareToUniverse()
        case .download:
            Task { await viewModel.save() }
        case .ready:
            glowsShare = true
            Task {
                try? await Task.sleep(for: .seconds(4))
                glowsShare = false
            }
        case .notYet, .back:
            break
        }
    }

    /// The Takes tab's Share or Edit, once, as the review opens.
    private func applyLaunchAction() {
        guard let launchAction, let take = viewModel.take else { return }
        onLaunchActionDone()
        switch launchAction {
        case .share: export(.share)
        case .continueQueue: continueQueue(nil)
        case .postLater(let network): continueQueue(network)
        case .edit: editingTake = take
        case .editTool(let tool):
            editingTool = tool
            editingTake = take
        case .pickBest: suggestBest()
        }
    }

    @ViewBuilder
    private func celebrationView(_ celebration: ExportCelebration) -> some View {
        switch celebration {
        case .readyToTravel(let video):
            ReadyToTravelView(video: video, review: viewModel, flow: flow, onClose: { viewModel.celebration = nil })
                .modifier(ShareFlowPresentations(flow: flow, review: viewModel))
                .modifier(ExportPresentations(viewModel: viewModel, isActive: flow.step == nil))
        case .sentOff(let video, let networks):
            SendOffView(
                video: video, networks: networks, snapshot: sentOffSnapshot(),
                onShareAgain: { shareAfterClosing(video) },
                onUniverse: { viewModel.celebration = nil; services.presentation.selectedTab = .profile; onBack() },
                onDone: { doneWithSendOff() },
                // One `.success` a story: with a milestone's icon to come, the icon's pop is the peak.
                endsStory: !personalization.celebrations || (reachedMilestone ?? flow.reachedMilestone) == nil
            )
        }
    }

    // MARK: - Share to universe

    /// The yellow button: the file is made (nothing leaves Cue, nothing is counted), "Ready to travel" comes up, and the networks with it.
    private func shareToUniverse() {
        playback.pause()
        Task {
            await viewModel.render()
            guard case .readyToTravel(let video)? = viewModel.celebration else { return }
            try? await Task.sleep(for: .milliseconds(550))
            flow.openPicker(with: video)
        }
    }

    /// "Continue posting" and "POST TO LINKEDIN LATER": the queue picks up where it was.
    private func continueQueue(_ network: ShareDestination?) {
        playback.pause()
        Task { await flow.resume(network) }
    }

    /// What the flow tells the review: the send-off when the networks are done, the editor when the creator wants to edit first.
    private func connectFlow() {
        flow.onFinished = { video, networks in
            // From "Ready to travel" to the send-off without the cover sliding down and up again: both are the same night.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { viewModel.celebration = .sentOff(video, networks) }
        }
        flow.onEditFirst = {
            viewModel.celebration = nil
            playback.pause()
            editingTake = viewModel.take
        }
    }

    /// The year's universe with the shares just confirmed in it.
    private func sentOffSnapshot() -> UniverseSnapshot {
        let videos = UniverseVideo.resolve(
            records: milestones.records, takes: services.takes.takes, scripts: services.library.scripts, fallbackDate: milestones.firstShareDate ?? .now
        )
        return UniverseSnapshot(videos: videos, year: UniverseYears.current(), topics: universeTopics)
    }

    /// UI tests (`-uiTestFirstStar`, `-uiTestMilestone`): the stories open on their own, to be looked at.
    /// After a swipe, "Take 2 of 3" shows for a moment.
    private func announcePlace() {
        guard arrivedFromNeighbor, viewModel.siblings.count > 1 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showsPlace = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.3)) { showsPlace = false }
        }
    }

    /// Save's ✓ once the video is in Photos, when nothing covers the screen ("Ready to travel" opens after a save): a light tap, then
    /// back to Save after a moment.
    private func showSavedCheck() {
        guard awaitsSavedCheck, viewModel.celebration == nil else { return }
        awaitsSavedCheck = false
        Haptics.light()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) { justSaved = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.3)) { justSaved = false }
        }
    }

    private func showStoriesForTests() {
        #if DEBUG
        if services.showsFirstStar { tellsFirstStar = true }
        if let milestone = services.milestoneToShow, AppIconChoice(milestone: milestone) != nil {
            reachedMilestone = milestone
            tellsMilestone = true
        }
        #endif
    }

    // MARK: - The first voyage

    /// The voyage's fourth step: keep the best take. Not over the stories, the editor or a celebration.
    private var showsPickTip: Bool {
        viewModel.take != nil && !tellsFirstStar && editingTake == nil && viewModel.celebration == nil
    }

    /// The take on screen, when it has siblings to compare with ("Compare" opens "Pick the best take").
    private var comparableTake: Take? {
        guard let take = viewModel.take, services.takes.siblings(of: take).count > 1 else { return nil }
        return take
    }

    private func pickTip(isDone: Bool) -> some View {
        VoyageTipCard(
            step: .pick, title: VoyageStep.pick.tipTitle(), message: VoyageStep.pick.tipMessage(),
            primary: comparableTake.map { _ in
                (VoyageStep.pick.tipAction(canCompare: true), {
                    services.voyage.tipActed(.pick, at: .review)
                    suggestBest()
                })
            },
            isDone: isDone,
            onClose: { withAnimation(.smooth(duration: 0.25)) { services.voyage.closeTip(.pick, at: .review) } }
        )
    }

    /// The first take Cue ever recorded (a video imported from Photos never is one) lights the first star (once, and only when the creator
    /// has done the first flight), at the end of a task: as the review of the recording opens, or when the edit it was opened for closes.
    /// Once a video is shared, the send-off told it.
    private func considerFirstStar() {
        let onboarding = services.onboarding
        guard onboarding.isCompleted, !onboarding.firstStarShown, personalization.celebrations,
              services.takes.takes.filter({ !$0.isImported }).count == 1, viewModel.take?.isImported == false,
              editingTake == nil, viewModel.celebration == nil else { return }
        onboarding.markFirstStarShown()
        guard services.milestones.shares == 0 else { return }
        tellsFirstStar = true
    }

    private func finishFirstStar(thenEdit take: Take? = nil) {
        tellsFirstStar = false
        services.guidance.celebrated()
        guard let take else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            editingTake = take
        }
    }

    /// The creator's topics, as the worlds around them.
    private var universeTopics: [OnboardingTopic] {
        let profile = services.profile.profile
        return Array((profile.niches.map(OnboardingTopic.niche) + profile.customTopics.map(OnboardingTopic.custom)).prefix(OnboardingTopic.limit))
    }

    /// "Done" on the send-off: the milestone it reached, if any, comes next.
    private func doneWithSendOff() {
        viewModel.celebration = nil
        services.guidance.celebrated()
        guard reachedMilestone != nil, personalization.celebrations else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            tellsMilestone = true
        }
    }

    private func finishMilestone(_ reached: Int) {
        services.guidance.celebrated()
        milestones.markCelebrated(reached)
        reachedMilestone = nil
        tellsMilestone = false
    }

    private func useMilestoneIcon(_ icon: AppIconChoice, reached: Int) {
        guard !icon.needsPro || store.tier.isPro else {
            finishMilestone(reached)
            viewModel.paywall = .profile
            return
        }
        Task {
            await appIcon.choose(icon)
            finishMilestone(reached)
        }
    }

    /// The system share sheet, once the celebration cover is gone (a view can't present while another cover leaves).
    private func shareAfterClosing(_ video: ExportedVideo) {
        viewModel.celebration = nil
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            viewModel.share(video)
        }
    }

    /// Opens "Pick your best take" with Cue's suggestion.
    private func suggestBest() {
        guard let found = viewModel.bestProposal() else { return }
        playback.pause()
        proposal = found
    }

    // MARK: - Playback

    /// Reloads the player when the take changes or is edited.
    /// What a tap exports (`export`).
    private enum ReviewExport {
        case save
        case share
    }

    /// Where a way out of the review goes (`leave`).
    private enum ReviewExit {
        case back
        case neighbor(Int)
    }

    private struct PlayerKey: Equatable {
        let takeID: UUID
        let edit: TakeEdit?
    }

    private func runPlayer() async {
        playback.pause()
        guard let url = viewModel.videoURL else { return }
        if let edit = viewModel.take?.edit, let item = try? await editing.previewItem(forVideoAt: url, edit: edit) {
            playback.load(item)
        } else {
            playback.load(AVPlayerItem(url: url))
        }
        guard !Task.isCancelled else { return }
        // Opens paused: the play button starts it.
        await playback.follow { viewModel.take?.duration ?? 0 }
    }
}
