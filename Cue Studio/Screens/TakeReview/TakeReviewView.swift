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

    @State private var flow: ShareFlow
    @State private var player = AVPlayer()
    @State private var audioSession = PlaybackAudioManager()
    @State private var playbackTask: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var progress: Double = 0

    /// "Pick your best take", opened by ✦ Suggest best.
    @State private var proposal: BestTakeProposal?
    @State private var editingTake: Take?
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
    /// The milestone a share just reached, told once the send-off is done.
    @State private var reachedMilestone: Int?
    @State private var tellsMilestone = false
    /// The first take ever: its star, told once.
    @State private var tellsFirstStar = false

    init(
        takeID: UUID, services: AppServices,
        onRetake: @escaping () -> Void, onBack: @escaping () -> Void,
        onSelect: @escaping (Take) -> Void, onDeleted: @escaping (Take?) -> Void,
        onOpenScript: @escaping (UUID) -> Void = { _ in },
        launchAction: ReviewLaunchAction? = nil, onLaunchActionDone: @escaping () -> Void = {}
    ) {
        let store = services.store
        let languages = services.languages
        let model = TakeReviewViewModel(
            takeID: takeID,
            takes: services.takes,
            quota: services.quota,
            tier: { store.tier },
            exporter: services.exporter,
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
            speechLanguage: { languages.captionRequest(for: $0) }
        )
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
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            Color.black.ignoresSafeArea()
            if let take = viewModel.take {
                video(for: take)
                chrome(for: take)
            } else {
                ContentUnavailableView("This take was deleted", systemImage: "film")
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
        .task(id: PlayerKey(takeID: viewModel.takeID, edit: viewModel.take?.edit)) { await runPlayer() }
        .onChange(of: viewModel.take?.edit?.showsCaptions ?? false) { _, shown in
            viewModel.burnsInCaptions = shown
        }
        .fullScreenCover(item: $editingTake, onDismiss: handleEditorOutcome) { take in
            QuickEditView(take: take, services: services) { outcome in
                pendingOutcome = outcome
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
        }
        .onChange(of: viewModel.celebration) { _, new in
            guard case .sentOff? = new else { return }
            // The networks the creator confirmed were counted as they were confirmed (`ShareFlow`); the milestone they reached is told after.
            reachedMilestone = flow.reachedMilestone
            if !personalization.celebrations { viewModel.celebration = nil }
        }
        .fullScreenCover(isPresented: $tellsFirstStar) {
            if let take = viewModel.take {
                FirstStarView(
                    take: take,
                    onStudio: { finishFirstStar() },
                    onEdit: { finishFirstStar(thenEdit: take) }
                )
            }
        }
        .fullScreenCover(isPresented: $tellsMilestone) {
            if let reached = reachedMilestone, let icon = AppIconChoice(milestone: reached) {
                MilestoneView(
                    milestone: reached, icon: icon, isAvailable: !icon.needsPro || store.tier.isPro,
                    onUse: { useMilestoneIcon(icon, reached: reached) },
                    onKeep: { finishMilestone(reached) }
                )
            }
        }
        .onAppear { connectFlow(); applyLaunchAction(); considerFirstStar(); showStoriesForTests() }
        .onDisappear { pausePlayback(); viewModel.leave() }
        .modifier(ExportPresentations(viewModel: viewModel, isActive: viewModel.celebration == nil))
    }

    // MARK: - Video

    private func video(for take: Take) -> some View {
        GeometryReader { proxy in
            let frame = frameSize(for: take.outputAspect, in: proxy.size)
            PlayerView(player: player)
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
        .contentShape(Rectangle())
        .onTapGesture { togglePlayback() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { drag in
                // A clear horizontal swipe goes to the next (left) or the previous (right) take.
                guard abs(drag.translation.width) > 60, abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                selectNeighbor(drag.translation.width < 0 ? 1 : -1)
            }
        )
        .overlay {
            if !isPlaying {
                Button { togglePlayback() } label: {
                    Image(systemName: "play.fill").offset(x: 2)
                }
                .buttonStyle(.cueIcon(.glass, diameter: 64))
                .accessibilityLabel(Text("Play"))
            }
        }
    }

    /// Portrait takes fill the screen; other frames are shown at their crop, letterboxed.
    private func frameSize(for aspect: AspectRatio, in size: CGSize) -> CGSize {
        guard aspect != .portrait else { return size }
        let height = size.width / aspect.widthOverHeight
        return CGSize(width: size.width, height: min(size.height, height))
    }

    // MARK: - Chrome

    private func chrome(for take: Take) -> some View {
        _ = editorVisits
        return VStack(spacing: 0) {
            ReviewTopBar(
                take: take,
                placeLabel: placeLabel(for: take),
                onBack: onBack,
                onToggleBest: viewModel.toggleBest,
                // Gone at once, with 4 s of Undo in the toast (04 · F4): no question first.
                onDelete: {
                    pausePlayback()
                    onDeleted(viewModel.delete())
                },
                onPrevious: viewModel.neighbor(-1) == nil ? nil : { selectNeighbor(-1) },
                onNext: viewModel.neighbor(1) == nil ? nil : { selectNeighbor(1) },
                onSuggest: viewModel.offersBestSuggestion ? { suggestBest(from: take) } : nil
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                ReviewScrubber(progress: progress, duration: take.duration) { seek(to: $0, of: take) }
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5).padding(.top, 14)
                ReviewInfoPanel(
                    take: take, stage: viewModel.stage, lengthFit: viewModel.lengthFit, scriptVersion: viewModel.scriptVersionLabel,
                    dotColor: themeColor(of: take)
                )
                    .padding(.top, 20)
                ReviewActionBar(
                    runningAction: viewModel.runningAction,
                    glowsShare: glowsShare,
                    editTitle: viewModel.hasOpenEdit ? String(localized: "Continue") : String(localized: "Edit"),
                    onEdit: {
                        pausePlayback()
                        editingTake = take
                    },
                    onRetake: onRetake,
                    onSave: { Task { await viewModel.save() } },
                    onScript: take.scriptID.map { id in { pausePlayback(); onOpenScript(id) } },
                    onShare: { shareToUniverse() }
                )
                .padding(.top, 22)
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
        guard let topic, let index = universeTopics.firstIndex(where: { $0.id == topic }) else { return Palette.worldWarm }
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
    private func selectNeighbor(_ offset: Int) {
        guard let next = viewModel.neighbor(offset) else { return }
        pausePlayback()
        onSelect(next)
    }

    /// The editor's Done question, answered: share opens "Share to", download saves to Photos (and
    /// counts as an export), ready later makes Share glow, and not yet or back change nothing here.
    private func handleEditorOutcome() {
        editorVisits += 1
        guard let outcome = pendingOutcome else { return }
        pendingOutcome = nil
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
        case .share: shareToUniverse()
        case .continueQueue: continueQueue(nil)
        case .postLater(let network): continueQueue(network)
        case .edit: editingTake = take
        case .pickBest: suggestBest(from: take)
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
                video: video, networks: networks, snapshot: sentOffSnapshot(networks),
                onShareAgain: { shareAfterClosing(video) },
                onUniverse: { viewModel.celebration = nil; services.presentation.selectedTab = .profile; onBack() },
                onDone: { doneWithSendOff() }
            )
        }
    }

    // MARK: - Share to universe

    /// The yellow button: the file is made (nothing leaves Cue, nothing is counted), "Ready to travel" comes up, and the networks with it.
    private func shareToUniverse() {
        pausePlayback()
        Task {
            await viewModel.render()
            guard case .readyToTravel(let video)? = viewModel.celebration else { return }
            try? await Task.sleep(for: .milliseconds(550))
            flow.openPicker(with: video)
        }
    }

    /// "Continue posting" and "POST TO LINKEDIN LATER": the queue picks up where it was.
    private func continueQueue(_ network: ShareDestination?) {
        pausePlayback()
        Task { await flow.resume(network) }
    }

    /// What the flow tells the review: the send-off when the networks are done, the editor when the creator wants to edit first.
    private func connectFlow() {
        flow.onFinished = { video, networks in
            viewModel.celebration = .sentOff(video, networks)
        }
        flow.onEditFirst = {
            viewModel.celebration = nil
            pausePlayback()
            editingTake = viewModel.take
        }
    }

    /// The year's universe with the shares just confirmed in it.
    private func sentOffSnapshot(_ networks: [ShareDestination]) -> UniverseSnapshot {
        let videos = UniverseVideo.resolve(
            records: milestones.records, takes: services.takes.takes, scripts: services.library.scripts, fallbackDate: milestones.firstShareDate ?? .now
        )
        return UniverseSnapshot(videos: videos, year: UniverseYears.current(), topics: universeTopics)
    }

    /// UI tests (`-uiTestFirstStar`, `-uiTestMilestone`): the stories open on their own, to be looked at.
    private func showStoriesForTests() {
        #if DEBUG
        if services.showsFirstStar { tellsFirstStar = true }
        if let milestone = services.milestoneToShow, AppIconChoice(milestone: milestone) != nil {
            reachedMilestone = milestone
            tellsMilestone = true
        }
        #endif
    }

    /// The first take Cue ever recorded lights the first star (once, and only when the creator has done the first flight).
    private func considerFirstStar() {
        let onboarding = services.onboarding
        guard onboarding.isCompleted, !onboarding.firstStarShown, personalization.celebrations,
              services.takes.takes.count == 1 else { return }
        onboarding.markFirstStarShown()
        tellsFirstStar = true
    }

    private func finishFirstStar(thenEdit take: Take? = nil) {
        tellsFirstStar = false
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
        guard reachedMilestone != nil, personalization.celebrations else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            tellsMilestone = true
        }
    }

    private func finishMilestone(_ reached: Int) {
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
    private func suggestBest(from take: Take) {
        guard let found = viewModel.bestProposal() else { return }
        pausePlayback()
        proposal = found
    }

    // MARK: - Playback

    /// Reloads the player when the take changes or is edited.
    private struct PlayerKey: Equatable {
        let takeID: UUID
        let edit: TakeEdit?
    }

    private func runPlayer() async {
        pausePlayback()
        guard let url = viewModel.videoURL else { return }
        if let edit = viewModel.take?.edit, let item = try? await editing.previewItem(forVideoAt: url, edit: edit) {
            player.replaceCurrentItem(with: item)
        } else {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
        guard !Task.isCancelled else { return }
        // Opens paused: the play button starts it.
        player.isMuted = isMuted
        while !Task.isCancelled {
            let duration = viewModel.take?.duration ?? 0
            let seconds = player.currentTime().seconds
            progress = duration > 0 && seconds.isFinite ? min(1, seconds / duration) : 0
            isPlaying = playbackTask != nil || player.timeControlStatus != .paused
            if progress >= 0.999 && !isPlaying {
                await player.seek(to: .zero)
                progress = 0
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        playbackTask?.cancel()
        isPlaying = true
        playbackTask = Task {
            await audioSession.prepareForPlayback()
            guard !Task.isCancelled else { return }
            playbackTask = nil
            player.play()
        }
    }

    private func pausePlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        player.pause()
        isPlaying = false
    }

    private func seek(to fraction: Double, of take: Take) {
        progress = fraction
        player.seek(to: CMTime(seconds: take.duration * fraction, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
