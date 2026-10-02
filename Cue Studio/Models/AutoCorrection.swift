//
//  AutoCorrection.swift
//  Cue Studio
//

import Foundation

/// What Adjust › Auto measured on a clip, kept as plain numbers so it plays the same on every
/// frame, every time and in the export, with no filter objects to keep around. It is a correction
/// of exposure, tone and color measured by Core Image on a few frames of the clip
/// (`CIImage.autoAdjustmentFilters`); it is not Apple Intelligence and not the Auto of Photos.
///
/// The parts are the ones Core Image's analysis offers for a picture: a tone curve, highlights and
/// shadows, vibrance and, when people are in it, a face balance. It never holds red-eye or any
/// crop. `scaled(by:)` is how much of it shows, the intensity the creator picks.
nonisolated struct AutoCorrection: Codable, Hashable, Sendable {
    /// A point of the tone curve, both 0 to 1.
    struct Point: Codable, Hashable, Sendable {
        var x: Double
        var y: Double
    }

    /// Color the faces were measured to have, and how much to balance it (`CIFaceBalance`).
    struct FaceBalance: Codable, Hashable, Sendable {
        var originI: Double
        var originQ: Double
        var strength: Double
        var warmth: Double
    }

    /// Bumped when the numbers mean something else, so a saved correction is never read wrong.
    static let currentVersion = 1
    /// The tone curve's neutral points (`CIToneCurve` takes five).
    static let neutralTone = (0...4).map { Point(x: Double($0) / 4, y: Double($0) / 4) }

    var version = AutoCorrection.currentVersion
    /// `CIVibrance`, −1…1.
    var vibrance: Double = 0
    /// `CIHighlightShadowAdjust` highlights, 0…1 (1 leaves them).
    var highlights: Double = 1
    /// `CIHighlightShadowAdjust` shadows, −1…1 (0 leaves them).
    var shadows: Double = 0
    /// Five points, left to right.
    var tone: [Point] = AutoCorrection.neutralTone
    var face: FaceBalance?

    init() {}

    /// Nothing to correct: the clip already looks balanced to the analysis.
    var isNeutral: Bool {
        abs(vibrance) < Self.tolerance && highlights > 1 - Self.tolerance && abs(shadows) < Self.tolerance
            && face == nil && tone.allSatisfy { abs($0.y - $0.x) < Self.tolerance }
    }

    /// Smallest change worth drawing.
    static let tolerance = 0.01

    /// A fraction of this correction, 0 (nothing) to 1 (all of it): every number moves from its
    /// neutral value toward its own.
    func scaled(by amount: Double) -> AutoCorrection {
        let share = min(max(amount, 0), 1)
        var result = self
        result.vibrance = vibrance * share
        result.highlights = 1 + (highlights - 1) * share
        result.shadows = shadows * share
        result.tone = tone.map { Point(x: $0.x, y: $0.x + ($0.y - $0.x) * share) }
        result.face = face.map { FaceBalance(originI: $0.originI, originQ: $0.originQ, strength: $0.strength * share, warmth: $0.warmth * share) }
        return result
    }

    // MARK: - From several frames

    /// The correction that most frames agree on: the median of each number, so one odd frame (a
    /// flash, a dark moment) never moves the whole clip. Faces count when most frames have them.
    /// Nil when there is nothing to take the median of.
    static func median(of corrections: [AutoCorrection]) -> AutoCorrection? {
        guard !corrections.isEmpty else { return nil }
        var result = AutoCorrection()
        result.vibrance = median(corrections.map(\.vibrance))
        result.highlights = median(corrections.map(\.highlights))
        result.shadows = median(corrections.map(\.shadows))
        result.tone = (0..<neutralTone.count).map { index in
            let points = corrections.compactMap { $0.tone.indices.contains(index) ? $0.tone[index] : nil }
            return Point(x: median(points.map(\.x)), y: median(points.map(\.y)))
        }
        let faces = corrections.compactMap(\.face)
        if faces.count * 2 > corrections.count {
            result.face = FaceBalance(
                originI: median(faces.map(\.originI)), originQ: median(faces.map(\.originQ)),
                strength: median(faces.map(\.strength)), warmth: median(faces.map(\.warmth))
            )
        }
        return result.limited()
    }

    /// The same, kept inside what is safe to put on any footage: a measurement from an odd frame
    /// never turns a clip orange, flat or crushed.
    func limited() -> AutoCorrection {
        var result = self
        result.vibrance = min(max(vibrance, Self.vibranceRange.lowerBound), Self.vibranceRange.upperBound)
        result.highlights = min(max(highlights, Self.highlightRange.lowerBound), 1)
        result.shadows = min(max(shadows, Self.shadowRange.lowerBound), Self.shadowRange.upperBound)
        result.tone = tone.map { Point(x: $0.x, y: min(max($0.y, $0.x - Self.toneShift), $0.x + Self.toneShift)) }
        result.face = face.map { FaceBalance(originI: $0.originI, originQ: $0.originQ, strength: min(max($0.strength, 0), 1), warmth: min(max($0.warmth, 0), 1)) }
        return result
    }

    static let vibranceRange = -0.3...0.8
    static let highlightRange = 0.6...1.0
    static let shadowRange = -0.2...0.6
    /// How far a point of the tone curve may sit from the diagonal.
    static let toneShift = 0.15

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
