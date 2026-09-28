//
//  SafeZoneMargins.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The creator's own safe zone ("Custom"): margins as percentages of the frame, so they fit any
/// frame and resolution.
nonisolated struct SafeZoneMargins: Codable, Hashable, Sendable {
    static let topRange: ClosedRange<Double> = 0...30
    static let bottomRange: ClosedRange<Double> = 0...35
    static let leftRange: ClosedRange<Double> = 0...20
    static let rightRange: ClosedRange<Double> = 0...25

    var top: Double = 11
    var bottom: Double = 22
    var left: Double = 6
    var right: Double = 11

    /// The clear part of a frame, in unit coordinates (the frame is 1 × 1).
    var unitContentRect: CGRect {
        let top = Self.fraction(self.top, in: Self.topRange)
        let bottom = Self.fraction(self.bottom, in: Self.bottomRange)
        let left = Self.fraction(self.left, in: Self.leftRange)
        let right = Self.fraction(self.right, in: Self.rightRange)
        return CGRect(x: left, y: top, width: 1 - left - right, height: 1 - top - bottom)
    }

    /// A percentage kept within its range, as a fraction.
    private static func fraction(_ percent: Double, in range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, percent)) / 100
    }
}
