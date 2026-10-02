//
//  TimelineLaneGutterView.swift
//  Cue Studio
//

import UIKit

/// The icons at the left of each track, on black: the content scrolls under them. A tap goes
/// through to the timeline (which opens the track's tools); the icons turn yellow while those
/// tools are open.
@MainActor
final class TimelineLaneGutterView: UIView {
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
        subviews.forEach { $0.removeFromSuperview() }
        guard let geometry else { return }
        for frame in geometry.lanes {
            guard let symbol = frame.lane.gutterSymbol else { continue }
            let cell = UIView(frame: CGRect(x: 0, y: frame.y, width: TimelineGeometry.gutterWidth, height: frame.height))
            cell.backgroundColor = UIColor(Palette.bg)
            let isActive = geometry.input.activeLanes.contains(frame.lane)
            let icon = UIImageView(image: UIImage(
                systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            ))
            icon.tintColor = UIColor(isActive ? Palette.acc : Palette.laneGutterInk)
            icon.contentMode = .center
            icon.frame = cell.bounds
            cell.addSubview(icon)
            addSubview(cell)
        }
    }
}
