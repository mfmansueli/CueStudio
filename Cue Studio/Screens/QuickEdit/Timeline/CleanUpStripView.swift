//
//  CleanUpStripView.swift
//  Cue Studio
//

import SwiftUI

/// Clean Up's slim timeline: the edited video's frames, a mark in each suggestion's color where it
/// sits (faint once kept), and the playhead. Touch or drag anywhere to move the playhead.
struct CleanUpStripView: View {
    let viewModel: QuickEditViewModel

    static let height: CGFloat = 30

    @GestureState private var isTouching = false

    var body: some View {
        leftToRightContent.environment(\.layoutDirection, .leftToRight)
    }

    /// Time, video and the camera frame run left to right in every language, Arabic included.
    @ViewBuilder private var leftToRightContent: some View {
        GeometryReader { proxy in
            let layout = TimelineLayout(timeline: viewModel.edit.timeline, width: proxy.size.width, inset: 0, showsTrimmedEnds: false)
            ZStack(alignment: .topLeading) {
                TimelineFramesView(
                    videoURL: viewModel.videoURL, layout: layout,
                    frameCount: TimelineLayout.frameCount(width: proxy.size.width, tileWidth: Self.height * 9 / 16)
                )
                .frame(width: proxy.size.width, height: Self.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                marks(layout)
                playhead(layout)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouching) { _, touching, _ in touching = true }
                    .onChanged { value in viewModel.scrub(to: layout.editedTime(atX: value.location.x)) }
                    .onEnded { _ in viewModel.endScrub() }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Timeline"))
            .accessibilityValue(Text(viewModel.timeLabel))
            .accessibilityAdjustableAction { direction in
                viewModel.nudgePlayhead(by: direction == .increment ? 1 : -1)
            }
            .accessibilityIdentifier("cleanUp.timeline")
        }
        .frame(height: Self.height)
        .onChange(of: isTouching) { _, touching in
            if !touching { viewModel.endScrub() }
        }
    }

    private func marks(_ layout: TimelineLayout) -> some View {
        ForEach(viewModel.cleanUpSuggestions) { suggestion in
            if let start = viewModel.editedStart(of: suggestion) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CleanUpKindColor.color(for: suggestion.kind))
                    .opacity(suggestion.status == .kept ? 0.35 : 0.95)
                    .frame(width: max(4, CGFloat(editedLength(of: suggestion)) * layout.pointsPerSecond), height: Self.height - 6)
                    .offset(x: layout.x(forEdited: start), y: 3)
                    .allowsHitTesting(false)
            }
        }
    }

    /// How long the suggestion plays in the edit (a sped-up section plays it shorter).
    private func editedLength(of suggestion: CleanUpSuggestion) -> TimeInterval {
        viewModel.edit.timeline.editedSpan(forSource: suggestion.span)?.duration ?? suggestion.span.duration
    }

    private func playhead(_ layout: TimelineLayout) -> some View {
        Rectangle()
            .fill(Palette.ink)
            .frame(width: 2, height: Self.height + 12)
            .shadow(color: Palette.textShadow, radius: 2)
            .offset(x: layout.x(forEdited: viewModel.player.currentTime) - 1, y: -6)
            .allowsHitTesting(false)
    }
}
