//
//  UniverseTilt.swift
//  Cue Studio
//

import CoreGraphics
import CoreMotion
import Foundation

/// The iPhone's tilt for Your universe's parallax (`UniverseParallax`), from the motion sensors (device motion's gravity, which needs no
/// permission): −1…1 on each axis away from how the iPhone was held when the map appeared, eased so a shaking hand never jitters the map, and
/// drifting back to centre over a few seconds, so holding the iPhone another way becomes the new rest. Read every frame by the map's timeline
/// (no observation: the map redraws anyway); zero where there is no sensor (the Simulator) or when it isn't running.
@MainActor
final class UniverseTilt {
    private let manager = CMMotionManager()
    private var rest: CMAcceleration?
    private(set) var tilt: CGVector = .zero

    /// The gravity change that counts as a full tilt (about 20°).
    private static let fullTilt = 0.35
    /// How fast the map follows the hand (per update, at 60 Hz) and how fast the rest follows the hand (a few seconds).
    private static let follow = 0.14
    private static let recentre = 0.004

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            MainActor.assumeIsolated { self?.take(gravity) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        rest = nil
        tilt = .zero
    }

    private func take(_ gravity: CMAcceleration) {
        guard var rest else {
            rest = gravity
            return
        }
        rest.x += (gravity.x - rest.x) * Self.recentre
        rest.y += (gravity.y - rest.y) * Self.recentre
        self.rest = rest
        let target = CGVector(dx: Self.clamp((gravity.x - rest.x) / Self.fullTilt), dy: Self.clamp((gravity.y - rest.y) / Self.fullTilt))
        tilt = CGVector(dx: tilt.dx + (target.dx - tilt.dx) * Self.follow, dy: tilt.dy + (target.dy - tilt.dy) * Self.follow)
    }

    private static func clamp(_ value: Double) -> CGFloat { CGFloat(max(-1, min(1, value))) }
}
