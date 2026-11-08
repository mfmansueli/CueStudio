//
//  CutZoom.swift
//  Cue Studio
//

import Foundation

/// Zoom › Punch in on cuts (E4, plan §11; owner's rule F16: only by the creator's choice): every other clip a little closer, so a
/// cut in a talking video reads as a second camera. One switch for the whole video, worked out when it is drawn
/// (`punched(_:)`), so it follows every cut made after it and turning it off takes away only what it put. Rules (decided
/// 08/11/2026, DESIGN_PROJECT §50):
/// - the first clip plays as filmed, and each real cut after it changes between as filmed and closer; where nothing was cut out
///   (a clip split to change one part) the picture stays as it was;
/// - a clip shorter than `minimumClip` keeps the level of the one before it, so a short stretch never jumps in and out;
/// - a clip the creator zoomed or cropped by hand keeps what they did (and counts as closer when it has a zoom of its own);
/// - its strength is a phrase zoom's (`PhraseZoom.Strength`), toward the face when one face is clearly in view (`ZoomAnchor`),
///   never past `PhraseZoom.maximumTotal` with a phrase zoom, never past what the recording's pixels allow.
nonisolated struct CutZoom: Codable, Hashable, Sendable {
    /// The shortest clip that changes the level at its cut, in edited seconds.
    static let minimumClip: TimeInterval = 1.2

    var strength: PhraseZoom.Strength = .medium

    init(strength: PhraseZoom.Strength = .medium) {
        self.strength = strength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strength = (try? container.decodeIfPresent(PhraseZoom.Strength.self, forKey: .strength)) ?? .medium
    }

    /// Each clip of `timeline`, by index: whether it plays closer because of the switch.
    func punchedClips(of timeline: EditTimeline) -> [Bool] {
        var punched: [Bool] = []
        var closer = false
        for (index, segment) in timeline.segments.enumerated() {
            let manual = segment.zoom != nil || segment.crop != nil
            if index == 0 {
                closer = segment.zoom != nil
            } else if timeline.continuesFromPrevious(index) || segment.duration < Self.minimumClip {
                // Nothing cut out, or too short to change: as the clip before it.
            } else {
                closer.toggle()
            }
            if manual { closer = segment.zoom != nil }
            punched.append(!manual && closer && index > 0)
        }
        return punched
    }

    /// `timeline` with the punch-ins written on its clips (`EditSegment.punchesInOnCut`): a hold of the strength's zoom for the
    /// whole clip.
    func punched(_ timeline: EditTimeline) -> EditTimeline {
        var result = timeline
        for (segment, isPunched) in zip(timeline.segments, punchedClips(of: timeline)) where isPunched {
            var closer = segment
            closer.zoom = .punchIn
            closer.zoomAmount = (strength.scale - 1) / SectionZoom.maximumDepth
            closer.punchesInOnCut = true
            _ = result.replaceSegment(closer)
        }
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case strength
    }
}
