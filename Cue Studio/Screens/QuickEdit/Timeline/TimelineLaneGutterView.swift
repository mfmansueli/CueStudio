//
//  TimelineLaneGutterView.swift
//  Cue Studio
//

import UIKit
import SwiftUI

/// The icons at the left of each track, on black: the content scrolls under them. A tap goes
/// through to the timeline (which opens the track's tools); the icons turn yellow while those
/// tools are open. The current track's icon has ▾ beside it (▴ while every track is out), in its colour.
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
            let ink = UIColor(isActive ? Palette.acc : Palette.Editor.laneGutterInk)
            let icon = UIImageView(image: UIImage(
                systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            ))
            icon.tintColor = ink
            icon.contentMode = .center
            icon.frame = cell.bounds
            cell.addSubview(icon)
            if let chooser = geometry.chooser, chooser.lane == frame.lane {
                place(icon, besideChevron: chooser.isExpanded ? "chevron.up" : "chevron.down", ink: ink, in: cell)
            }
            addSubview(cell)
        }
    }

    /// The icon and the chevron side by side, centred together in the cell.
    private func place(_ icon: UIImageView, besideChevron symbol: String, ink: UIColor, in cell: UIView) {
        let chevron = UIImageView(image: UIImage(
            systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        ))
        chevron.tintColor = ink
        chevron.contentMode = .center
        let iconWidth = icon.image?.size.width ?? 16
        let chevronWidth = chevron.image?.size.width ?? 8
        let gap: CGFloat = 2
        let start = (cell.bounds.width - iconWidth - gap - chevronWidth) / 2
        icon.frame = CGRect(x: start, y: 0, width: iconWidth, height: cell.bounds.height)
        chevron.frame = CGRect(x: start + iconWidth + gap, y: 0, width: chevronWidth, height: cell.bounds.height)
        cell.addSubview(chevron)
    }
}
