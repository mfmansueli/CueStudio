//
//  FrameShift.swift
//  Cue Studio
//

import Foundation

/// How a recording's picture moved from one frame to the next (the camera's shake and pans, seen as the whole picture
/// sliding and turning): measured by Vision's registration of the two frames, on the upright frame. What stabilization smooths.
nonisolated struct FrameShift: Codable, Hashable, Sendable {
    /// Seconds of the recording (the later frame).
    var time: TimeInterval
    /// How far the picture slid, as fractions of the frame's width and height (right and down are positive).
    var dx: Double
    var dy: Double
    /// How far it turned, in radians (clockwise on screen is positive).
    var angle: Double

    init(time: TimeInterval, dx: Double, dy: Double, angle: Double = 0) {
        self.time = time
        self.dx = dx.isFinite ? dx : 0
        self.dy = dy.isFinite ? dy : 0
        self.angle = angle.isFinite ? angle : 0
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        time = try container.decode(TimeInterval.self)
        dx = try container.decode(Double.self)
        dy = try container.decode(Double.self)
        angle = (try? container.decode(Double.self)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode((time * 10000).rounded() / 10000)
        try container.encode(Float(dx))
        try container.encode(Float(dy))
        try container.encode(Float(angle))
    }
}
