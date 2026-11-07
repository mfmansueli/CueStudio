//
//  TimelineLaneGutterView.swift
//  Cue Studio
//

import UIKit
import SwiftUI

/// The icons at the left of each track, on black: the content scrolls under them, and they grow with the track
/// (`TimelineLaneLook`). A tap goes through to the timeline (which opens the track's tools). Each track keeps its cell
/// (`TimelineLaneGutterCell`), so when the tracks come out or go away the cells glide to their new places (0.3 s, as the
/// timeline grows), the ones coming in fade in and the ones leaving fade out; with Reduce Motion they are put in place. Under
/// a finger dragging the timeline (`TimelineGeometry.Input.reveal`) they follow it, with their tracks' fade.
@MainActor
final class TimelineLaneGutterView: UIView {
    private var geometry: TimelineGeometry?
    private var cells: [TimelineLane: TimelineLaneGutterCell] = [:]
    /// Lay out without motion (the first time, or a new height class).
    private var placesAtOnce = true
    /// The track brought under the video by this update: it rises into place.
    private var arriving: TimelineLane?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ geometry: TimelineGeometry, change: TimelineChange = .none) {
        // A new height class, or tracks on their way under a finger (or just let go of one): they're put in place.
        placesAtOnce = self.geometry == nil || self.geometry?.input.heightClass != geometry.input.heightClass
            || geometry.input.reveal != nil || self.geometry?.input.reveal != nil
        self.geometry = geometry
        arriving = change.arrivedLane
        setNeedsLayout()
    }

    /// A finger on the current track's square, or off it.
    func press(_ down: Bool) {
        guard let lane = geometry?.chooser?.lane else { return }
        cells[lane]?.press(down)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let geometry else { return }
        let animated = !placesAtOnce && window != nil
        let moves = animated && !UIAccessibility.isReduceMotionEnabled
        placesAtOnce = false
        var kept: Set<TimelineLane> = []
        for frame in geometry.lanes where frame.lane.gutterSymbol != nil {
            kept.insert(frame.lane)
            let target = CGRect(x: 0, y: frame.y, width: TimelineGeometry.gutterWidth, height: frame.height)
            let state = TimelineLaneGutterCell.State(
                lane: frame.lane, height: frame.height,
                isCurrent: geometry.chooser?.lane == frame.lane,
                turn: geometry.chooser?.lane == frame.lane ? geometry.chooser?.turn ?? 0 : 0,
                trackCount: geometry.chooser?.trackCount ?? 0,
                isActive: geometry.input.activeLanes.contains(frame.lane)
            )
            if let cell = cells[frame.lane] {
                cell.apply(state, animated: animated)
                if !animated { cell.alpha = frame.opacity }
                guard cell.frame != target else { continue }
                if moves {
                    UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                        cell.frame = target
                        cell.layoutIfNeeded()
                    }
                } else {
                    cell.frame = target
                }
            } else {
                let cell = TimelineLaneGutterCell(frame: target)
                cell.apply(state, animated: false)
                cells[frame.lane] = cell
                addSubview(cell)
                cell.alpha = frame.opacity
                if arriving == frame.lane, animated {
                    cell.arrive()
                } else if animated {
                    cell.alpha = 0
                    UIView.animate(withDuration: 0.22, delay: 0, options: [.allowUserInteraction]) { cell.alpha = 1 }
                }
            }
        }
        arriving = nil
        // The current track's cell over the others while they gather under it.
        if let lane = geometry.chooser?.lane, let cell = cells[lane], subviews.last !== cell { bringSubviewToFront(cell) }
        for (lane, cell) in cells where !kept.contains(lane) {
            cells[lane] = nil
            guard animated else {
                cell.removeFromSuperview()
                continue
            }
            UIView.animate(withDuration: 0.16, delay: 0, options: [.allowUserInteraction]) {
                cell.alpha = 0
            } completion: { _ in
                cell.removeFromSuperview()
            }
        }
    }
}
