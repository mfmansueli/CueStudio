//
//  RemoteSceneLayout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where the two devices of Settings › Remote's scene stand (`RemoteHero`) and the arc of light between them: the teleprompter on the
/// left, a little bigger, and the remote on the right, lower, out of step. Pairing brings the teleprompter to the middle, bigger, its
/// screen turned into the code, and sends the remote away; linked, the two come back and lean in. A change of stage moves them on a
/// critically damped spring (`settle`), so they glide in and stop without a bounce. Pure, so tested.
nonisolated struct RemoteSceneLayout: Equatable, Sendable {
    struct Device: Equatable, Sendable {
        var center: CGPoint
        var width: CGFloat
        /// Degrees, clockwise.
        var tilt: Double
        var opacity: Double

        var height: CGFloat { RemoteSceneLayout.height(forWidth: width) }
    }

    var prompter: Device
    var remote: Device
    /// How much of the teleprompter's screen is the pairing code (0: the script, 1: the code).
    var code: Double

    /// The scene's height on the page.
    static let sceneHeight: CGFloat = 244
    /// Seconds a device floats up and back down.
    static let floatPeriod: TimeInterval = 4.2
    static let floatReach: CGFloat = 4

    /// A device's height for its width: an iPhone's proportions.
    static func height(forWidth width: CGFloat) -> CGFloat { width * 2.05 }

    static func layout(for stage: RemoteStage, width: CGFloat) -> Self {
        let middle = width / 2
        switch stage {
        case .apart:
            return Self(
                prompter: Device(center: CGPoint(x: middle - 62, y: 118), width: 92, tilt: 0, opacity: 1),
                remote: Device(center: CGPoint(x: middle + 92, y: 134), width: 62, tilt: 0, opacity: 1),
                code: 0
            )
        case .pairing:
            return Self(
                prompter: Device(center: CGPoint(x: middle, y: 120), width: 110, tilt: 0, opacity: 1),
                remote: Device(center: CGPoint(x: middle + 158, y: 156), width: 44, tilt: 10, opacity: 0),
                code: 1
            )
        case .linked:
            return Self(
                prompter: Device(center: CGPoint(x: middle - 64, y: 118), width: 92, tilt: 2.5, opacity: 1),
                remote: Device(center: CGPoint(x: middle + 94, y: 130), width: 62, tilt: -4, opacity: 1),
                code: 0
            )
        }
    }

    /// From `self` to `target`, `progress` of the way (0…1).
    func interpolated(to target: Self, progress: Double) -> Self {
        Self(
            prompter: Self.mix(prompter, target.prompter, progress),
            remote: Self.mix(remote, target.remote, progress),
            code: code + (target.code - code) * progress
        )
    }

    /// The scene `time` seconds in: each device floating on its own beat (the remote half a period behind), less while it is the
    /// teleprompter showing its code, so the code holds still enough to scan.
    func floating(at time: TimeInterval) -> Self {
        var floated = self
        let phase = time / Self.floatPeriod * 2 * .pi
        floated.prompter.center.y += sin(phase) * Self.floatReach * (1 - 0.6 * code)
        floated.remote.center.y += sin(phase + .pi) * Self.floatReach
        return floated
    }

    // MARK: - The link

    /// The arc of light: from the remote's shoulder to the teleprompter's side, rising over the gap between them.
    var link: (start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        let start = CGPoint(x: remote.center.x - remote.width / 2 - 3, y: remote.center.y - remote.height * 0.12)
        let end = CGPoint(x: prompter.center.x + prompter.width / 2 + 3, y: prompter.center.y - prompter.height * 0.05)
        let lift = max(36, (start.x - end.x) * 0.75)
        return (start, CGPoint(x: start.x - 14, y: start.y - lift), CGPoint(x: end.x + 14, y: end.y - lift), end)
    }

    /// The point `fraction` of the way along the link (0: at the remote, 1: at the teleprompter).
    func linkPoint(at fraction: Double) -> CGPoint {
        let (p0, p1, p2, p3) = link
        let t = min(1, max(0, fraction))
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }

    // MARK: - Timing

    /// A critically damped spring from 0 to 1, `elapsed` seconds after it starts: quick, then a long settle, no overshoot (99% by 0.75 s).
    static func settle(_ elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        let omega = 9.0
        return min(1, 1 - (1 + omega * elapsed) * exp(-omega * elapsed))
    }

    /// Something popping into place `elapsed` seconds after it starts: past its size, back, and settled (a light spring).
    static func pop(_ elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        return max(0, 1 - exp(-9 * elapsed) * cos(11 * elapsed))
    }

    /// Light's curve: fast, then a long settle, from 0 to 1 over `duration`.
    static func ease(_ elapsed: TimeInterval, over duration: TimeInterval) -> Double {
        let x = min(1, max(0, elapsed / duration))
        return 1 - pow(1 - x, 3)
    }

    private static func mix(_ from: Device, _ to: Device, _ progress: Double) -> Device {
        Device(
            center: CGPoint(x: from.center.x + (to.center.x - from.center.x) * progress, y: from.center.y + (to.center.y - from.center.y) * progress),
            width: from.width + (to.width - from.width) * progress,
            tilt: from.tilt + (to.tilt - from.tilt) * progress,
            opacity: from.opacity + (to.opacity - from.opacity) * progress
        )
    }
}
