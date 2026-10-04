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

    @State private var confirmsDelete = false
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
        .confirmationDialog("Delete this take?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete take", role: .destructive) {
                pausePlayback()
                onDeleted(viewModel.delete())
            }
        } message: {
            Text("The video is removed from Cue. Copies you saved to Photos stay there.")
        }
        .onAppear { applyLaunchAction() }
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
                onDelete: { confirmsDelete = true }
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
        }
    }

    /// Switches to the suggested take (or opens the paywall on the free plan).
    private func suggestBest(from take: Take) {
        guard let best = viewModel.suggestBest(), best.id != take.id else { return }
        pausePlayback()
        onSelect(best)
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
