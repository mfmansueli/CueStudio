//
//  EditorTimelineView.swift
//  Cue Studio
//

import SwiftUI

/// The UIKit timeline (`TimelineScrollingView`) in the editor: SwiftUI hands it what to draw
/// whenever the edit, the selection, the panel or the zoom change, and the player's clock moves its content
/// directly (observed here, so the rest of the screen doesn't redraw 60 times a second).
struct EditorTimelineView: UIViewRepresentable {
    let viewModel: QuickEditViewModel
    let heightClass: EditorHeightClass

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> TimelineScrollingView {
        let view = TimelineScrollingView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: TimelineScrollingView, context: Context) {
        view.update(input: viewModel.timelineInput(heightClass: heightClass), sources: sources)
    }

    static func dismantleUIView(_ view: TimelineScrollingView, coordinator: Coordinator) {
        view.cancelLoading()
        coordinator.stop()
    }

    private var sources: TimelineContentView.Sources {
        var coverTime: TimeInterval = 0.5
        if case .frame(let time)? = viewModel.edit.cover?.source { coverTime = time }
        return TimelineContentView.Sources(take: viewModel.videoURL, others: viewModel.clipSourceURLs, coverTime: coverTime)
    }

    @MainActor
    final class Coordinator {
        private let viewModel: QuickEditViewModel
        private weak var view: TimelineScrollingView?
        private var isStopped = false

        init(viewModel: QuickEditViewModel) {
            self.viewModel = viewModel
        }

        func attach(to view: TimelineScrollingView) {
            self.view = view
            let viewModel = viewModel
            view.actions = TimelineScrollingView.Actions(
                scrub: { viewModel.scrubTimeline(to: $0) },
                endScrub: { viewModel.endTimelineScrub() },
                tap: { viewModel.tapTimeline($0) },
                beginHandle: { viewModel.beginTimelineHandle($0, snapTimes: $1) },
                moveHandle: { viewModel.moveTimelineHandle(by: $0) },
                endHandle: { viewModel.endTimelineHandle() },
                zoom: { viewModel.setTimelineZoom($0) },
                nudge: { viewModel.nudgePlayhead(by: $0) },
                selectClipAtPlayhead: { viewModel.selectClipAtPlayhead() },
                pickNearestCut: { viewModel.pickNearestJoin() },
                accessibilityValue: { viewModel.timelineAccessibilityValue }
            )
            view.show(time: viewModel.player.currentTime)
            followClock()
        }

        func stop() {
            isStopped = true
        }

        /// Moves the content with the player's clock, and keeps listening.
        private func followClock() {
            guard !isStopped else { return }
            withObservationTracking {
                _ = viewModel.player.currentTime
            } onChange: { [weak self] in
                Task { @MainActor in
                    guard let self, !self.isStopped else { return }
                    self.view?.show(time: self.viewModel.player.currentTime)
                    self.followClock()
                }
            }
        }
    }
}
