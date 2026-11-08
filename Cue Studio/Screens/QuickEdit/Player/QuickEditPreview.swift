//
//  QuickEditPreview.swift
//  Cue Studio
//

import SwiftUI

/// The edit playing in its frame. Tap to play or pause (a play sign shows while paused); with the
/// Crop tool, dragging moves the crop; with Text or Media, handles move what is laid on the video
/// (`OverlayEditingLayer`). Says so
/// when the recording can't be opened, and shows "Processing…" when a change takes a moment to
/// build. While the screen is recorded or mirrored it carries Cue's mark on the free plan (`CaptureWatermark`).
struct QuickEditPreview: View {
    let viewModel: QuickEditViewModel
    let size: CGSize
    /// Full screen: a tap plays or pauses, and nothing laid on the video can be picked.
    var isFullScreen = false
    /// The arrow at the video's foot (`PreviewFullScreenArrow`): in the editor while the video isn't growing or shown full screen.
    var showsFullScreenArrow = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.previewStandInFrame) private var standInFrame
    @SceneCaptured private var isSceneCaptured
    @State private var dragStartOffset: Double?

    var body: some View {
        drawing.keepsLeftToRight()
    }

    @ViewBuilder
    private var drawing: some View {
        QuickEditPlayerView(player: viewModel.player, holdsFirstFrame: isFullScreen)
            .frame(width: size.width, height: size.height)
            .background(Palette.Editor.previewWell)
            .overlay {
                // UI tests: a white or black frame for the video the Simulator can't play.
                if let standInFrame { Rectangle().fill(standInFrame.color).allowsHitTesting(false) }
            }
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
                // Under the handles, so a text or a window at the edge stays reachable.
                if !isFullScreen, viewModel.showsSafeGuideOverlay {
                    SafeGuideOverlay(size: size, content: viewModel.look.safeGuideRect(in: size))
                        .transition(.opacity)
                }
            }
            .overlay {
                // Under Voice-over's script (`NarrationScriptOverlay`) the handles would only draw over the words.
                if !isFullScreen, viewModel.panel != .crop, viewModel.panel != .clipCrop, !viewModel.showsNarrationScriptOverlay {
                    OverlayEditingLayer(viewModel: viewModel, size: size)
                }
            }
            .overlay {
                if !isFullScreen, viewModel.panel == .clipCrop {
                    ClipCropLayer(viewModel: viewModel, size: size)
                }
            }
            .overlay(alignment: .topLeading) {
                if !isFullScreen, viewModel.showsSafeGuideOverlay {
                    SafeGuideBadge(look: viewModel.look, maxWidth: size.width - 16)
                        .padding([.top, .leading], 8)
                        .transition(.opacity)
                }
            }
            .overlay { recordingBadge }
            .overlay { status }
            // The video, a held frame, the cover and everything laid on them, signed on the free plan while the screen is recorded.
            .captureWatermarked(isSceneCaptured)
            .overlay(alignment: .bottom) {
                // In full screen the arrow sits over the screen's hint (`FullScreenLayer`).
                if showsFullScreenArrow {
                    PreviewFullScreenArrow(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 0 : Metrics.editorPreviewRadius, style: .continuous))
            .gesture(cropDrag, isEnabled: viewModel.panel == .crop && !isFullScreen)
            .onTapGesture {
                if isFullScreen {
                    if !viewModel.audio.isRecordingVoiceOver { viewModel.togglePlayback() }
                } else if viewModel.panel != .crop, viewModel.panel != .clipCrop {
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
        if viewModel.isReady, viewModel.player.state == .ready, !viewModel.player.isPlaying {
            Image(systemName: "play.fill")
                .font(.editorGlyph(EditorGlyph.player, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .offset(x: 2)
                .frame(width: 54, height: 54)
                .glassEffect(.regular, in: Circle())
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
        }
    }

    /// "● REC 00:04.20" at the top while a voice-over records; "Original audio" while Voice compares with the untreated sound;
    /// "Original" while ◐ shows the picture as recorded.
    @ViewBuilder
    private var recordingBadge: some View {
        if viewModel.audio.isRecordingVoiceOver {
            HStack(spacing: 6) {
                Circle().fill(Palette.record).frame(width: 8, height: 8)
                Text("REC \(viewModel.audio.recordingElapsedLabel)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.Takes.durationBadge, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("edit.recordingBadge")
        } else if viewModel.audio.comparesOriginal {
            // Voice › Compare with original: what plays is the untreated sound.
            HStack(spacing: 6) {
                Image(systemName: "ear").font(.editorGlyph(EditorGlyph.small, weight: .bold)).foregroundStyle(Palette.accText)
                Text("Original audio").font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.Takes.durationBadge, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("edit.originalAudioBadge")
        } else if viewModel.blur.comparesOriginal || viewModel.overlays.comparesWithoutMask {
            // ◐ in Blur area or Mask: the video without what they change.
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled").font(.editorGlyph(EditorGlyph.small, weight: .bold)).foregroundStyle(Palette.accText)
                // A narrow preview (a panel open) wraps the words instead of cutting them.
                Text(viewModel.blur.comparesOriginal ? String(localized: "Without Blur areas") : String(localized: "Without the mask"))
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .background(Palette.Takes.durationBadge, in: RoundedRectangle(cornerRadius: Metrics.editorCardRadius, style: .continuous))
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("edit.comparedBadge")
        } else if viewModel.look.comparesPicture || viewModel.look.comparesSkin {
            // ◐ in Adjust, Filters or Background: the picture as recorded; in Skin, the video without Skin.
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled").font(.editorGlyph(EditorGlyph.small, weight: .bold)).foregroundStyle(Palette.accText)
                if viewModel.look.comparesSkin {
                    Text("Without Skin", comment: "Video editor preview badge while ◐ in Skin shows the video without Skin").font(.footnote.weight(.semibold))
                } else {
                    Text("Original").font(.footnote.weight(.semibold))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.Takes.durationBadge, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("edit.originalPictureBadge")
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
            VStack(spacing: 4) {
                message(
                    title: Text("The preview couldn't be built"),
                    detail: Text("Your edit is safe. Try again, or cancel and open the take again.")
                )
                Button("Try again", action: viewModel.retryPreview)
                    .buttonStyle(CueStudioButtonStyle(variant: .glass, size: .compact))
                    .accessibilityIdentifier("edit.previewRetry")
            }
        } else if viewModel.source == .loading || viewModel.player.state == .loading {
            ProgressView().tint(Palette.ink)
        } else if viewModel.player.isProcessing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Palette.ink)
                Text("Processing…").font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Palette.Takes.durationBadge, in: Capsule())
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
                if dragStartOffset == nil { viewModel.look.beginCropMove() }
                dragStartOffset = start
                let wide = viewModel.edit.aspect.widthOverHeight > 9.0 / 16.0
                let travel = wide ? value.translation.width / max(1, size.width) : value.translation.height / max(1, size.height)
                viewModel.look.moveCrop(to: start - Double(travel) * 2)
            }
            .onEnded { _ in
                dragStartOffset = nil
                viewModel.endPanelChange()
            }
    }
}
