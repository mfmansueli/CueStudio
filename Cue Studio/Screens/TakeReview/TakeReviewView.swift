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
        _viewModel = State(initialValue: TakeReviewViewModel(
            takeID: takeID,
            takes: services.takes,
            quota: services.quota,
            tier: { store.tier },
            exporter: services.exporter,
            photos: services.photos,
            apps: services.apps,
            editing: services.editing,
            library: services.library,
            rules: services.rules,
            profile: services.profile,
            preferences: services.preferences,
            drafts: services.drafts,
            toast: services.toast,
            speechLanguage: { languages.captionRequest(for: $0) }
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
            guard case .sentOff(let video, _)? = new else { return }
            // Every platform share counts, whether or not the story plays.
            if let reached = milestones.recordShare(of: video.take.id) { reachedMilestone = reached }
            if !personalization.celebrations { viewModel.celebration = nil }
        }
        .fullScreenCover(isPresented: $tellsFirstStar) {
            if let take = viewModel.take {
                FirstStarView(
                    take: take, topics: universeTopics,
                    onStudio: { finishFirstStar() },
                    onEdit: { finishFirstStar(thenEdit: take) }
                )
            }
        }
        .fullScreenCover(isPresented: $tellsMilestone) {
            if let reached = reachedMilestone, let icon = AppIconChoice(milestone: reached) {
                MilestoneView(
                    milestone: reached, icon: icon, since: milestones.firstShareDate, isAvailable: !icon.needsPro || store.tier.isPro,
                    onUse: { useMilestoneIcon(icon, reached: reached) },
                    onKeep: { finishMilestone(reached) }
                )
            }
        }
        .onAppear { applyLaunchAction(); considerFirstStar() }
        .onDisappear { pausePlayback() }
        .sheet(isPresented: $viewModel.showsShareSheet) {
            if let take = viewModel.take {
                ShareToSheet(viewModel: viewModel, take: take)
                    .modifier(ExportPresentations(viewModel: viewModel, isActive: true))
            }
        }
        .modifier(ExportPresentations(viewModel: viewModel, isActive: !viewModel.showsShareSheet))
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
                .buttonStyle(.cueIcon(.glass, diameter: 76))
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
                onBack: onBack,
                onToggleBest: viewModel.toggleBest,
                // Gone at once, with 4 s of Undo in the toast (04 · F4): no question first.
                onDelete: {
                    pausePlayback()
                    onDeleted(viewModel.delete())
                }
            )
            .padding(.horizontal, 14)
            if let place = viewModel.placeLabel, let index = viewModel.siblings.firstIndex(where: { $0.id == take.id }) {
                ReviewCompareChip(
                    count: viewModel.siblings.count, index: index, label: place,
                    onPrevious: viewModel.neighbor(-1) == nil ? nil : { selectNeighbor(-1) },
                    onNext: viewModel.neighbor(1) == nil ? nil : { selectNeighbor(1) }
                )
                .padding(.top, 8)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                if let url = viewModel.videoURL { scrubber(take: take, url: url) }
                ReviewInfoPanel(
                    take: take,
                    stage: viewModel.stage,
                    lengthFit: viewModel.lengthFit,
                    scriptVersion: viewModel.scriptVersionLabel,
                    onOpenScript: take.scriptID.map { id in { pausePlayback(); onOpenScript(id) } },
                    onSuggest: viewModel.offersBestSuggestion ? { suggestBest(from: take) } : nil
                )
                ReviewActionBar(
                    runningAction: viewModel.runningAction,
                    glowsShare: glowsShare,
                    shareTitle: take.platform.map { String(localized: "Share to \($0.label)") } ?? String(localized: "Share"),
                    editTitle: viewModel.hasOpenEdit ? String(localized: "Continue") : String(localized: "Edit"),
                    onEdit: {
                        pausePlayback()
                        editingTake = take
                    },
                    onRetake: onRetake,
                    onSave: { Task { await viewModel.save() } },
                    onShare: {
                        pausePlayback()
                        viewModel.showsShareSheet = true
                    }
                )
                if viewModel.photosDenied {
                    PhotosDeniedCard { viewModel.photosDenied = false }
                }
                if let notice = viewModel.exportNotice {
                    ReviewExportFooter(notice: notice, isExhausted: viewModel.exportsExhausted) {
                        // "You've used your 5 free exports" is for when they are gone; with some left it is just browsing.
                        viewModel.paywall = viewModel.exportsExhausted ? .export : .profile
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
    }

    /// The frames across the take with the playhead and the sound button, and the clock under it:
    /// the time in yellow, the length in gray.
    private func scrubber(take: Take, url: URL) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                FilmstripView(take: take, videoURL: url, progress: progress) { fraction in
                    seek(to: fraction, of: take)
                }
                Button {
                    isMuted.toggle()
                    player.isMuted = isMuted
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.cueIcon(.glass, diameter: 40))
                .accessibilityLabel(Text(isMuted ? "Unmute" : "Mute"))
                .accessibilityIdentifier("review.muteButton")
            }
            HStack {
                Text(DurationText.clock(take.duration * progress)).foregroundStyle(Palette.accText)
                Spacer()
                Text(DurationText.clock(take.duration)).foregroundStyle(Palette.ink2)
            }
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .padding(.trailing, 50)
        }
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
            viewModel.showsShareSheet = true
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
        case .share: viewModel.showsShareSheet = true
        case .edit: editingTake = take
        case .pickBest: suggestBest(from: take)
        }
    }

    @ViewBuilder
    private func celebrationView(_ celebration: ExportCelebration) -> some View {
        switch celebration {
        case .readyToTravel(let video):
            ReadyToTravelView(
                video: video,
                onShare: { destination in Task { await viewModel.send(video, to: destination) } },
                onOtherApps: { shareAfterClosing(video.url) },
                onClose: { viewModel.celebration = nil }
            )
        case .sentOff(let video, let destination):
            SendOffView(
                video: video, destination: destination,
                onShareAgain: { shareAfterClosing(video.url) },
                onUniverse: { viewModel.celebration = nil; services.presentation.selectedTab = .profile; onBack() },
                onDone: { doneWithSendOff() }
            )
        }
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
    private func shareAfterClosing(_ url: URL) {
        viewModel.celebration = nil
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            viewModel.shareURL = url
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
