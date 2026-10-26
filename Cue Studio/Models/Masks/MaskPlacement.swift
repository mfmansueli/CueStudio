//
//  MaskPlacement.swift
//  Cue Studio
//

import Foundation

/// Where a mask sits on the photo or video it shows a part of, as shares of the media's own place (its window, or the whole
/// frame), from its top left: its center, width and height, how far it's turned (degrees, clockwise), how soft its edge is
/// and how round a rectangle's corners are. A line uses its center and turn; a band, its thickness (`height`). It's what a
/// keyframe can move, so a mask can grow, travel or soften over time.
nonisolated struct MaskPlacement: Codable, Hashable, Sendable {
    /// Smallest and largest a mask can be, as a share of its media's side.
    static let sizeRange: ClosedRange<Double> = 0.05...2
    /// How far outside its media a mask's center may go, so it can still be grabbed and brought back.
    static let centerRange: ClosedRange<Double> = -0.5...1.5

    var center = OverlayPoint.center
    var width = 0.6
    var height = 0.6
    /// Degrees, clockwise.
    var rotation = 0.0
    /// 0 to 1: how soft the edge is (1 spreads it over a fifth of the media's shorter side).
    var feather = 0.0
    /// 0 to 1: how round a rectangle's corners are (1 makes its shorter side a half circle).
    var corners = 0.0

    init(center: OverlayPoint = .center, width: Double = 0.6, height: Double = 0.6, rotation: Double = 0, feather: Double = 0, corners: Double = 0) {
        self.center = center
        self.width = width
        self.height = height
        self.rotation = rotation
        self.feather = feather
        self.corners = corners
    }

    /// Every value inside its range (and a turn between -180 and 180).
    var clamped: MaskPlacement {
        var result = self
        func inside(_ value: Double, _ range: ClosedRange<Double>, or fallback: Double) -> Double {
            value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
        }
        result.center = OverlayPoint(x: inside(center.x, Self.centerRange, or: 0.5), y: inside(center.y, Self.centerRange, or: 0.5))
        result.width = inside(width, Self.sizeRange, or: 0.6)
        result.height = inside(height, Self.sizeRange, or: 0.6)
        var turn = rotation.isFinite ? rotation.truncatingRemainder(dividingBy: 360) : 0
        if turn > 180 { turn -= 360 }
        if turn <= -180 { turn += 360 }
        result.rotation = turn
        result.feather = inside(feather, 0...1, or: 0)
        result.corners = inside(corners, 0...1, or: 0)
        return result
    }

    /// The way from this placement to `other`, `progress` (0 to 1) along it; the turn takes the short way round.
    func interpolated(to other: MaskPlacement, progress: Double) -> MaskPlacement {
        let part = min(max(progress, 0), 1)
        func mix(_ from: Double, _ to: Double) -> Double { from + (to - from) * part }
        var turn = other.rotation - rotation
        if turn > 180 { turn -= 360 }
        if turn < -180 { turn += 360 }
        return MaskPlacement(
            center: OverlayPoint(x: mix(center.x, other.center.x), y: mix(center.y, other.center.y)),
            width: mix(width, other.width), height: mix(height, other.height), rotation: rotation + turn * part,
            feather: mix(feather, other.feather), corners: mix(corners, other.corners)
        )
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case center, width, height, rotation, feather, corners
    }

    /// Lenient: what's missing or unreadable reads as its default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        center = (try? container.decodeIfPresent(OverlayPoint.self, forKey: .center)) ?? .center
        width = (try? container.decodeIfPresent(Double.self, forKey: .width)) ?? 0.6
        height = (try? container.decodeIfPresent(Double.self, forKey: .height)) ?? 0.6
        rotation = (try? container.decodeIfPresent(Double.self, forKey: .rotation)) ?? 0
        feather = (try? container.decodeIfPresent(Double.self, forKey: .feather)) ?? 0
        corners = (try? container.decodeIfPresent(Double.self, forKey: .corners)) ?? 0
    }
}
