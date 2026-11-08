//
//  FaceZoomFocus.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where a recording's one face is, for a zoom to grow toward it (`ZoomAnchor`; plan §11: toward the face when the detection is
/// reliable, never switching person). Read once from the whole recording's analysis, so every zoom in it grows around the same
/// point and nothing moves while it does; nil when it can't be trusted, and the zoom then grows from the middle as it always did:
/// - a face in less than `foundShare` of the moments (the creator turned away or out of the frame much of the time);
/// - a second face of a real size (at least `secondFaceSize` of the first's) in `severalShare` of the moments or more: two people,
///   and no person is chosen for the creator;
/// - the face wandering: the farthest tenth of its moments further than `steadyReach` from where it mostly is.
/// Vision's confidence isn't kept (a face under 0.5 is never stored), so a weak detection shows as moments without a face. Pure.
nonisolated struct FaceZoomFocus: Hashable, Sendable {
    /// Where the face mostly is, on the upright frame (fractions, from the top left).
    let center: CGPoint
    /// The head around it (the face's box grown to the hair and chin) and as far as it wanders, on the upright frame.
    let head: NormalizedBox

    static let foundShare = 0.8
    static let severalShare = 0.1
    static let secondFaceSize = 0.3
    static let steadyReach = 0.12

    static func of(_ analysis: MotionAnalysis) -> FaceZoomFocus? {
        let samples = analysis.subjects
        guard !samples.isEmpty else { return nil }
        let faced = samples.filter { !$0.faces.isEmpty }
        guard Double(faced.count) >= foundShare * Double(samples.count) else { return nil }
        let several = faced.filter { $0.faces.count > 1 && $0.faces[1].area >= secondFaceSize * $0.faces[0].area }
        guard Double(several.count) < severalShare * Double(faced.count) else { return nil }
        let faces = faced.map { $0.faces[0] }
        let center = CGPoint(x: median(faces.map(\.midX)), y: median(faces.map(\.midY)))
        let distances = faces.map { hypot($0.midX - center.x, $0.midY - center.y) }.sorted()
        let reach = distances[min(distances.count - 1, Int(Double(distances.count) * 0.9))]
        guard reach <= steadyReach else { return nil }
        let width = median(faces.map(\.width)), height = median(faces.map(\.height))
        // The face's box leaves out the hair and most of the forehead: the head reaches about half a face above it.
        let top = center.y - height * 0.5 - height * 0.45 - reach
        let bottom = center.y + height * 0.5 + height * 0.1 + reach
        let left = center.x - width * 0.7 - reach, right = center.x + width * 0.7 + reach
        return FaceZoomFocus(center: center, head: NormalizedBox(x: left, y: top, width: right - left, height: bottom - top))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0.5 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
