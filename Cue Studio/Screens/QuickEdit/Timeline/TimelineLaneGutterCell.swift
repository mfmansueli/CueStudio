//
//  TimelineLaneGutterCell.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// One track's icon in the gutter, in its colour (`TimelineLaneTint`). The current track's icon has ▾ beside it on a square of
/// its hue, stronger while the track's tools are open: the square sinks while a finger is on it and springs back on release,
/// and ▾ turns to ▴ with a spring while every track is out (under a finger dragging the timeline, as far as the tracks are
/// out). With Reduce Motion nothing moves: the colours change in place.
@MainActor
final class TimelineLaneGutterCell: UIView {
    struct State: Equatable {
        var lane: TimelineLane
        var height: CGFloat
        /// The current track: the square and ▾.
        var isCurrent: Bool
        /// How far ▾ has turned to ▴ (`TimelineGeometry.Chooser.turn`).
        var turn: CGFloat
        /// Its tools are open on the toolbar.
        var isActive: Bool
    }

    /// The square, the icon and ▾ together: what sinks under a finger and rises into place.
    private let body = UIView()
    private let square = UIView()
    private let icon = UIImageView()
    private let chevron = UIImageView()
    private(set) var state: State?
    private var isPressed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(Palette.bg)
        square.layer.cornerCurve = .continuous
        square.layer.borderWidth = 1
        icon.contentMode = .center
        chevron.contentMode = .center
        body.addSubview(square)
        body.addSubview(icon)
        body.addSubview(chevron)
        addSubview(body)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static var reducesMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    func apply(_ next: State, animated: Bool) {
        let previous = state
        guard next != previous else { return }
        state = next
        let look = TimelineLaneLook(laneHeight: next.height)
        let previousLook = previous.map { TimelineLaneLook(laneHeight: $0.height) }
        if previous?.lane != next.lane || previousLook?.gutterSymbolSize != look.gutterSymbolSize
            || previousLook?.chevronSize != look.chevronSize {
            icon.image = next.lane.gutterSymbol.flatMap {
                UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: look.gutterSymbolSize, weight: .semibold))
            }
            chevron.image = UIImage(
                systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: look.chevronSize, weight: .bold)
            )
        }
        let ink = UIColor(TimelineLaneTint.ink(of: next.lane))
        icon.tintColor = ink
        chevron.tintColor = ink
        square.isHidden = !next.isCurrent
        chevron.isHidden = !next.isCurrent
        if next.isCurrent { paintSquare() }
        square.layer.cornerRadius = look.chooserRadius
        setNeedsLayout()
        turnChevron(to: next.turn, animated: animated && previous?.isCurrent == true && previous?.lane == next.lane)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let state else { return }
        body.bounds = bounds
        body.center = CGPoint(x: bounds.midX, y: bounds.midY)
        let look = TimelineLaneLook(laneHeight: state.height)
        square.frame = CGRect(
            x: (bounds.width - TimelineLaneLook.chooserWidth) / 2, y: (bounds.height - look.chooserHeight) / 2,
            width: TimelineLaneLook.chooserWidth, height: look.chooserHeight
        )
        let iconWidth = icon.image?.size.width ?? 16
        guard state.isCurrent else {
            icon.frame = bounds
            return
        }
        // The icon and ▾ side by side, centred together on the square.
        let chevronWidth = chevron.image?.size.width ?? 8
        let gap: CGFloat = 2
        let start = (bounds.width - iconWidth - gap - chevronWidth) / 2
        icon.frame = CGRect(x: start, y: 0, width: iconWidth, height: bounds.height)
        // By bounds and centre: it may be turned.
        chevron.bounds = CGRect(x: 0, y: 0, width: chevronWidth, height: chevronWidth)
        chevron.center = CGPoint(x: start + iconWidth + gap + chevronWidth / 2, y: bounds.midY)
    }

    /// A finger came down on the current track's square (it sinks) or left it (it springs back).
    func press(_ down: Bool) {
        guard state?.isCurrent == true, down != isPressed else { return }
        isPressed = down
        paintSquare()
        guard !Self.reducesMotion else { return }
        if down {
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
                self.body.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }
        } else {
            UIView.animate(springDuration: 0.45, bounce: 0.45, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.body.transform = .identity
            }
        }
    }

    /// The current track came in under the video (another track was brought): it rises 4 pt into place, the square popping
    /// back to its size with a spring. With Reduce Motion it only fades in.
    func arrive() {
        body.alpha = 0
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction]) { self.body.alpha = 1 }
        guard !Self.reducesMotion else { return }
        body.transform = CGAffineTransform(translationX: 0, y: 4).scaledBy(x: 0.92, y: 0.92)
        UIView.animate(springDuration: 0.45, bounce: 0.35, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.body.transform = .identity
        }
    }

    private func paintSquare() {
        guard let state else { return }
        let lane = state.lane
        square.backgroundColor = UIColor(TimelineLaneTint.square(of: lane, pressed: isPressed || state.isActive))
        square.layer.borderColor = UIColor(TimelineLaneTint.ring(of: lane)).cgColor
    }

    /// ▾ down, or turned up (▴) while every track is out: with a spring that passes the mark a little (under a finger, as far
    /// as it has turned, at once).
    private func turnChevron(to turn: CGFloat, animated: Bool) {
        let angle = .pi * turn
        let layer = chevron.layer
        let from = (layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
        layer.setValue(angle, forKeyPath: "transform.rotation.z")
        guard animated, !Self.reducesMotion, abs(from - angle) > 0.01 else {
            layer.removeAnimation(forKey: "turn")
            return
        }
        let spring = CASpringAnimation(perceptualDuration: 0.45, bounce: 0.35)
        spring.keyPath = "transform.rotation.z"
        spring.fromValue = from
        spring.toValue = angle
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "turn")
    }
}
