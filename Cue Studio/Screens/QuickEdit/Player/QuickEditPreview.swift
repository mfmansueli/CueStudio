//
//  QuickEditPreview.swift
//  Cue Studio
//

import SwiftUI

/// The edit playing in its frame. Tap to play or pause (a play sign shows while paused); with the
/// Crop tool, dragging moves the crop. Says so when the recording can't be opened, and shows
/// "Processing…" when a change takes a moment to build.
struct QuickEditPreview: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragStartOffset: Double?

    var body: some View {
        PlayerView(player: viewModel.player.avPlayer)
            .frame(width: size.width, height: size.height)
            .background(Palette.previewWell)
            .overlay {
                if viewModel.tool == .crop {
                    ThirdsGrid()
                        .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            .overlay { status }
            .overlay { playBadge }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
            .gesture(cropDrag, isEnabled: viewModel.tool == .crop)
            .onTapGesture {
                // With Crop, touches move the crop instead.
                if viewModel.tool != .crop { viewModel.togglePlayback() }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: size)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Preview"))
            .accessibilityValue(Text(statusDescription ?? ""))
            .accessibilityHint(Text("Tap to play or pause"))
            .accessibilityAddTraits(.startsMediaSession)
            .accessibilityIdentifier("edit.preview")
    }

    /// A play sign in the middle while paused, so a tap's result is obvious. Not a button: the whole
    /// preview is.
    @ViewBuilder
    private var playBadge: some View {
        if viewModel.isReady, viewModel.player.state == .ready, !viewModel.player.isPlaying, viewModel.tool != .crop {
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
                .foregroundStyle(Palette.warn)
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
