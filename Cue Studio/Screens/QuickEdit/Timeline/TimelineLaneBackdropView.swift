//
//  TimelineLaneBackdropView.swift
//  Cue Studio
//

import UIKit

/// The strip each track sits on, behind the scrolling content. It stays on screen while the
/// content moves, so an empty track is still something to tap; the strip of a track whose tools
/// are open lights up with a yellow ring.
@MainActor
final class TimelineLaneBackdropView: UIView {
    private var geometry: TimelineGeometry?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ geometry: TimelineGeometry) {
        self.geometry = geometry
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let geometry else { return }
        let width = max(0, bounds.width - TimelineGeometry.stripLeading - TimelineGeometry.stripTrailing)
        for frame in geometry.lanes where frame.lane != .main {
            let isActive = geometry.input.activeLanes.contains(frame.lane)
            let strip = CALayer()
            strip.frame = CGRect(x: TimelineGeometry.stripLeading, y: frame.y, width: width, height: frame.height)
            strip.cornerRadius = Metrics.laneItemRadius + 2
            strip.cornerCurve = .continuous
            strip.backgroundColor = UIColor(isActive ? Palette.laneStripActive : Palette.laneStrip).cgColor
            if isActive {
                strip.borderWidth = 1.5
                strip.borderColor = UIColor(Palette.laneStripRing).cgColor
            }
            layer.addSublayer(strip)
        }
    }
}
