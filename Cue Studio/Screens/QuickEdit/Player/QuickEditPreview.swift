//
//  QuickEditPreview.swift
//  Cue Studio
//

import SwiftUI

/// The edit playing in its frame. Tap to play or pause (a play sign shows while paused); with the
/// Crop tool, dragging moves the crop; with Text or Media, handles move what is laid on the video
/// (`OverlayEditingLayer`); with Cover, the cover shows instead (`CoverPreviewLayer`). Says so
/// when the recording can't be opened, and shows "Processing…" when a change takes a moment to
/// build.
struct QuickEditPreview: View {
    let viewModel: QuickEditViewModel
    let size: CGSize
    /// Full screen: a tap plays or pauses, and nothing laid on the video can be picked.
    var isFullScreen = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragStartOffset: Double?

    var body: some View {
        drawing.keepsLeftToRight()
    }

    @ViewBuilder
    private var drawing: some View {
        QuickEditPlayerView(player: viewModel.player)
            .frame(width: size.width, height: size.height)
            .background(Palette.previewWell)
            .overlay {
                if viewModel.panel == .crop {
                    ThirdsGrid()
                        .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if isFullScreen { playBadge }
            }
            .overlay {
                if !isFullScreen, viewModel.panel != .crop, !viewModel.showsCoverImage {
                    OverlayEditingLayer(viewModel: viewModel, size: size)
                }
            }
            .overlay {
                if viewModel.showsCoverImage {
                    CoverPreviewLayer(viewModel: viewModel, size: size)
                }
            }
            .overlay { recordingBadge }
            .overlay { status }
            .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 0 : Metrics.editorPreviewRadius, style: .continuous))
            .gesture(cropDrag, isEnabled: viewModel.panel == .crop && !isFullScreen)
            .onTapGesture {
                if isFullScreen {
                    if !viewModel.isRecordingVoiceOver { viewModel.togglePlayback() }
                } else if viewModel.panel != .crop {
                    viewModel.tapOutsideVideo()
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: size)
            // With handles on it, they stay reachable on their own.
            .accessibilityElement(children: isFullScreen ? .combine : .contain)
            .accessibilityLabel(Text("Preview"))
            .accessibilityValue(Text(statusDescription ?? ""))
            .accessibilityHint(isFullScreen ? Text("Tap to play or pause") : Text(""))
            .accessibilityAddTraits(.startsMediaSession)
            .accessibilityIdentifier("edit.preview")
    }

    /// A play sign in the middle while paused, so a tap's result is obvious. Not a button: the whole
    /// preview is.
    @ViewBuilder
    private var playBadge: some View {
        if viewModel.isReady, viewModel.player.state == .ready, !viewModel.player.isPlaying, !viewModel.showsCoverImage {
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .offset(x: 2)
                .frame(width: 54, height: 54)
                .glassEffect(.regular, in: Circle())
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
        }
    }

    /// "● REC 00:04.20" at the top while a voice-over records; "Original audio" while Voice
    /// compares with the untreated sound.
    @ViewBuilder
    private var recordingBadge: some View {
        if viewModel.isRecordingVoiceOver {
            HStack(spacing: 6) {
                Circle().fill(Palette.record).frame(width: 8, height: 8)
                Text("REC \(viewModel.recordingElapsedLabel)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.durationBadge, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("edit.recordingBadge")
        } else if viewModel.comparesOriginal {
            // Voice › Compare with original: what plays is the untreated sound.
            HStack(spacing: 6) {
                Image(systemName: "ear").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.accText)
                Text("Original audio").font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.durationBadge, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("edit.originalAudioBadge")
        }
    }

    /// What VoiceOver reads after "Preview" when something is wrong or slow.
    private var statusDescription: String? {
        if viewModel.source == .unavailable { return String(localized: "This video can't be opened") }
        if viewModel.player.state == .failed { return String(localized: "The preview couldn't be built") }
        if viewModel.player.isProcessing { return String(localized: "Processing…") }
        return nil
    }

    @ViewBuilder
    private var status: some View {
        if viewModel.source == .unavailable {
            message(
                title: Text("This video can't be opened"),
                detail: Text("It may have been deleted or damaged. The original take isn't changed.")
            )
        } else if viewModel.player.state == .failed {
            message(
                title: Text("The preview couldn't be built"),
                detail: Text("Try another change, or cancel and open the take again.")
            )
        } else if viewModel.source == .loading || viewModel.player.state == .loading {
            ProgressView().tint(Palette.ink)
        } else if viewModel.player.isProcessing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Palette.ink)
                Text("Processing…").font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Palette.durationBadge, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
        }
    }

    private func message(title: Text, detail: Text) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Palette.warnText)
            title.font(.subheadline.weight(.semibold))
            detail.font(.footnote).foregroundStyle(Palette.ink2)
        }
        .multilineTextAlignment(.center)
        .padding(20)
    }

    private var cropDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartOffset ?? viewModel.edit.cropOffset
                dragStartOffset = start
                let wide = viewModel.edit.aspect.widthOverHeight > 9.0 / 16.0
                let travel = wide ? value.translation.width / max(1, size.width) : value.translation.height / max(1, size.height)
                viewModel.edit.cropOffset = min(1, max(-1, start - Double(travel) * 2))
            }
            .onEnded { _ in dragStartOffset = nil }
    }
}
