//
//  TimelineLaneBackdropView.swift
//  Cue Studio
//

import UIKit
import SwiftUI

/// The strip each track sits on, behind the scrolling content. It stays on screen while the content moves, so an empty track is
/// still something to tap. Each strip has a touch of its track's colour, the current track's more (`TimelineLaneTint`); the
/// strip of a track whose tools are open lights up in its colour too, with a ring of it. When an item comes in, its strip
/// flashes in its colour, and a track brought under the video rises into place (`TimelineMotion`).
@MainActor
final class TimelineLaneBackdropView: UIView {
    private var geometry: TimelineGeometry?
    /// The strips, drawn again on each layout.
    private let strips = CALayer()
    /// Flashes over the strips, left to fade out whatever is drawn meanwhile.
    private let flashes = CALayer()
    /// What the next layout plays (`show(_:change:)`).
    private var flashing: Set<TimelineLane> = []
    private var arriving: TimelineLane?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.addSublayer(strips)
        layer.addSublayer(flashes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ geometry: TimelineGeometry, change: TimelineChange = .none) {
        self.geometry = geometry
        flashing.formUnion(change.addedLanes)
        arriving = change.arrivedLane ?? arriving
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        strips.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let geometry else { return }
        let width = max(0, bounds.width - TimelineGeometry.stripLeading - TimelineGeometry.stripTrailing)
        for frame in geometry.lanes where frame.lane != .main {
            let isActive = geometry.input.activeLanes.contains(frame.lane)
            let radius = TimelineLaneLook(laneHeight: frame.height).radius + 2
            let rect = CGRect(x: TimelineGeometry.stripLeading, y: frame.y, width: width, height: frame.height)
            let strip = CALayer()
            strip.frame = rect
            strip.cornerRadius = radius
            strip.cornerCurve = .continuous
            strip.opacity = Float(frame.opacity)
            let isCurrent = geometry.chooser?.lane == frame.lane
            strip.backgroundColor = TimelineLaneTint.strip(of: frame.lane, isCurrent: isCurrent || isActive).cgColor
            if isActive {
                strip.borderWidth = 1.5
                strip.borderColor = TimelineLaneTint.litRing(of: frame.lane).cgColor
            }
            strips.addSublayer(strip)
            if flashing.contains(frame.lane) {
                TimelineMotion.flash(in: flashes, frame: rect, radius: radius, color: TimelineLaneTint.flash(of: frame.lane))
            }
            if arriving == frame.lane, window != nil { TimelineMotion.rise(strip) }
        }
        flashing = []
        arriving = nil
    }
}
