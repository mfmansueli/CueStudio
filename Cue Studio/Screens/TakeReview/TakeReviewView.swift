//
//  TakeReviewView.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI

/// Watch the take, mark the best one, then retake, save or share.
struct TakeReviewView: View {
    @State private var viewModel: TakeReviewViewModel
    let onRetake: () -> Void
    let onBack: () -> Void
    /// Another take of the same script, from the strip.
    let onSelect: (Take) -> Void
    /// After deleting: the take to show next, or nil to leave the review.
    let onDeleted: (Take?) -> Void

    @State private var player = AVPlayer()
    @State private var audioSession = PlaybackAudioManager()
    @State private var playbackTask: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var progress: Double = 0

    @State private var confirmsDelete = false
    @State private var editingTake: Take?
    private let services: AppServices
    @Environment(TakeEditService.self) private var editing

    init(
        takeID: UUID, services: AppServices,
        onRetake: @escaping () -> Void, onBack: @escaping () -> Void,
        onSelect: @escaping (Take) -> Void, onDeleted: @escaping (Take?) -> Void
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
            toast: services.toast,
            speechLanguage: { languages.captionRequest(for: $0) }
        ))
        self.services = services
        self.onRetake = onRetake
        self.onBack = onBack
        self.onSelect = onSelect
        self.onDeleted = onDeleted
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
        .task(id: PlayerKey(takeID: viewModel.takeID, edit: viewModel.take?.edit)) { await runPlayer() }
        .onChange(of: viewModel.take?.edit?.showsCaptions ?? false) { _, shown in
            viewModel.burnsInCaptions = shown
        }
        .fullScreenCover(item: $editingTake) { take in
            QuickEditView(take: take, services: services) { editingTake = nil }
        }
        .confirmationDialog("Delete this take?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete take", role: .destructive) {
                pausePlayback()
                onDeleted(viewModel.delete())
            }
        } message: {
            Text("The video is removed from Cue. Copies you saved to Photos stay there.")
        }
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
        VStack(spacing: 0) {
            ReviewTopBar(
                take: take,
                onBack: onBack,
                onToggleBest: viewModel.toggleBest,
                onDelete: { confirmsDelete = true }
            )
            .padding(.horizontal, 14)
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                if let url = viewModel.videoURL {
                    VStack(spacing: 6) {
                        FilmstripView(take: take, videoURL: url, progress: progress) { fraction in
                            seek(to: fraction, of: take)
                        }
                        HStack {
                            Text(DurationText.clock(take.duration * progress))
                            Spacer()
                            Text(DurationText.clock(take.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.ink2)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(take.scriptTitle)
                            .font(.title3.bold())
                            .lineLimit(1)
                        if take.isEdited {
                            Text("EDITED")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.info)
                                .padding(.horizontal, 7)
                                .frame(height: 20)
                                .background(Palette.infoSoft, in: Capsule())
                        }
                    }
                    Text(viewModel.metaLine)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                    if let notice = viewModel.exportNotice {
                        HStack(spacing: 8) {
                            Text(notice).foregroundStyle(viewModel.exportsExhausted ? Palette.warn : Palette.ink2)
                            Button("Go Pro") { viewModel.paywall = .export }
                                .fontWeight(.semibold)
                                .foregroundStyle(Palette.acc)
                        }
                        .font(.footnote)
                        .padding(.top, 4)
                    }
                }
                if viewModel.siblings.count > 1 {
                    YourTakesStrip(
                        takes: viewModel.siblings,
                        currentID: take.id,
                        onSuggest: viewModel.offersBestSuggestion ? { suggestBest(from: take) } : nil
                    ) { sibling in
                        guard sibling.id != take.id else { return }
                        pausePlayback()
                        onSelect(sibling)
                    }
                }
                ReviewActionBar(
                    runningAction: viewModel.runningAction,
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
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
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
        startPlayback()
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
