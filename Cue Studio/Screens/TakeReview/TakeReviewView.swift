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

    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var progress: Double = 0

    init(takeID: UUID, services: AppServices, onRetake: @escaping () -> Void, onBack: @escaping () -> Void) {
        let store = services.store
        _viewModel = State(initialValue: TakeReviewViewModel(
            takeID: takeID,
            takes: services.takes,
            quota: services.quota,
            tier: { store.tier },
            exporter: services.exporter,
            photos: services.photos,
            toast: services.toast
        ))
        self.onRetake = onRetake
        self.onBack = onBack
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
        .task(id: viewModel.takeID) { await runPlayer() }
        .onDisappear { player.pause() }
        .sheet(isPresented: Binding(get: { viewModel.shareURL != nil }, set: { if !$0 { viewModel.shareURL = nil } })) {
            if let url = viewModel.shareURL {
                ActivityView(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $viewModel.paywall) { context in
            PaywallView(
                context: context,
                onWatermarkInstead: { Task { await viewModel.exportWithWatermark() } },
                onPurchased: { Task { await viewModel.continueAfterPurchase() } }
            )
        }
    }

    // MARK: - Video

    private func video(for take: Take) -> some View {
        GeometryReader { proxy in
            let frame = frameSize(for: take.aspect, in: proxy.size)
            PlayerView(player: player)
                .frame(width: frame.width, height: frame.height)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.exportsExhausted { watermarkBadge.padding(18) }
                }
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

    private var watermarkBadge: some View {
        HStack(spacing: 6) {
            Capsule().fill(Palette.acc).frame(width: 12, height: 3)
            Text("Made with Cue").font(.caption.weight(.bold))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    // MARK: - Chrome

    private func chrome(for take: Take) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Image(systemName: "chevron.backward") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("review.backButton")
                Spacer()
                HStack(spacing: 8) {
                    Text(take.label)
                    Text(DurationText.clock(take.duration))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink2)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .glassEffect(.regular, in: Capsule())
                Spacer()
                Button { viewModel.toggleBest() } label: { Image(systemName: "star.fill") }
                    .buttonStyle(.cueIcon(take.isBest ? .accent : .glass, diameter: 40))
                    .accessibilityLabel(Text("Best take"))
                    .accessibilityValue(Text(take.isBest ? "On" : "Off"))
                    .accessibilityIdentifier("review.bestButton")
            }
            .padding(.horizontal, 14)
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                if let url = viewModel.videoURL {
                    VStack(spacing: 8) {
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
                    Text(take.scriptTitle)
                        .font(.title3.bold())
                        .lineLimit(1)
                    Text(meta(for: take))
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
                        .padding(.top, 6)
                    }
                }
                HStack(spacing: 10) {
                    Button(action: onRetake) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.cueGlass())
                    .accessibilityIdentifier("review.retakeButton")
                    Button {
                        Task { await viewModel.save() }
                    } label: {
                        if viewModel.runningAction == .save {
                            ProgressView().tint(.white)
                        } else {
                            Label("Save", systemImage: "arrow.down.to.line")
                        }
                    }
                    .buttonStyle(.cueGlass())
                    .accessibilityIdentifier("review.saveButton")
                    Button {
                        Task { await viewModel.share() }
                    } label: {
                        if viewModel.runningAction == .share {
                            ProgressView().tint(Palette.accInk)
                        } else {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.cuePrimary())
                    .accessibilityIdentifier("review.shareButton")
                }
                .disabled(viewModel.runningAction != nil)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
    }

    private func meta(for take: Take) -> String {
        let when = take.recordedAt.formatted(.relative(presentation: .named))
        return "\(when) · \(take.resolution.label) · \(take.frameRate.rawValue) fps · \(take.aspect.label)"
    }

    // MARK: - Playback

    private func runPlayer() async {
        guard let url = viewModel.videoURL else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        while !Task.isCancelled {
            let duration = viewModel.take?.duration ?? 0
            let seconds = player.currentTime().seconds
            progress = duration > 0 && seconds.isFinite ? min(1, seconds / duration) : 0
            isPlaying = player.timeControlStatus != .paused
            if progress >= 0.999 && !isPlaying {
                await player.seek(to: .zero)
                progress = 0
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func togglePlayback() {
        if player.timeControlStatus == .paused {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }

    private func seek(to fraction: Double, of take: Take) {
        progress = fraction
        player.seek(to: CMTime(seconds: take.duration * fraction, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
