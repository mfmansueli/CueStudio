//
//  ZoomAnchor.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How the zooms Cue makes (Punch in on cuts, a phrase zoom) grow on one clip, worked out once per clip so the preview, the export
/// and the handles over the preview read the same (plan §11, decided 08/11/2026):
/// - **toward the face**: around the point where the recording's one face is (`FaceZoomFocus`), so the face stays where it is and
///   everything grows around it; the middle when the face can't be trusted, Follow face already moves the frame with it, or a
///   support of the split screen shows;
/// - **never cutting the head**: no closer than keeps the head inside the frame (`headLimit`), when the face is known;
/// - **never past the pixels**: no closer than leaves `minimumPixels` of the recording across the frame's short side, whatever
///   the export's quality (so the preview and every export zoom alike). A horizontal video cropped to 9:16 has about 606: it
///   gets 1.12× at most, a 1080p take 2×.
/// A zoom the creator picked for the clip (Zoom › Push in, Pull out, Punch in) stays as it was: from the middle, never limited;
/// a phrase zoom over it adds only what these limits allow. Pure.
nonisolated struct ZoomAnchor: Hashable, Sendable {
    /// The fewest of the recording's pixels a zoom leaves across the frame's short side: half of 1080p, past which a phone's
    /// screen shows the picture soft.
    static let minimumPixels: Double = 540

    /// The point of the frame the zoom grows around (fractions, from the top left).
    var pivot: OverlayPoint = .center
    /// The head on the frame (fractions, from the top left), when one face is clearly in view.
    var head: CGRect?
    /// The closest the recording's pixels allow.
    var resolutionLimit: Double = .infinity

    /// Grows toward a face.
    var followsFace: Bool { head != nil }

    /// The closest the zooms Cue makes can go here: what the pixels allow, and what keeps the head inside the frame around `pivot`.
    func limit(around pivot: OverlayPoint) -> Double {
        max(1, min(resolutionLimit, headLimit(around: pivot)))
    }

    /// The closest Cue's zooms go on this clip, around its own point.
    var limit: Double { limit(around: pivot) }

    /// Times the frame, and the point it grows around, for the clip's own zoom at `section` (`sectionIsManual`: one the creator
    /// picked, else Punch in on cuts' or none) and the phrase zooms with it at `combined` (`PhraseZoomWindow.combined`).
    func zoom(section: Double, sectionIsManual: Bool, combined: Double) -> (scale: Double, pivot: OverlayPoint) {
        guard combined > 1.000_1 else { return (combined, .center) }
        if sectionIsManual {
            // The creator's own zoom stays as they set it; a phrase zoom over it adds only what the limits allow.
            return (min(combined, max(section, limit(around: .center))), .center)
        }
        return (min(combined, limit), pivot)
    }

    /// The closest a zoom around `pivot` goes with the head's every edge still inside the frame (an edge already past the frame's
    /// can't be helped and doesn't count).
    func headLimit(around pivot: OverlayPoint) -> Double {
        guard let head else { return .infinity }
        var limit = Double.infinity
        func keep(_ near: Double, _ far: Double, _ middle: Double) {
            if near > 0, near < middle { limit = min(limit, middle / (middle - near)) }
            if far < 1, far > middle { limit = min(limit, (1 - middle) / (far - middle)) }
        }
        keep(head.minX, head.maxX, pivot.x)
        keep(head.minY, head.maxY, pivot.y)
        return limit
    }

    /// The anchor of a clip placed as `placement` says (without its zoom or Animation), its recording's face `face` (nil: none to
    /// trust), at `time` (seconds of the recording: Stabilize moves the frame, the clip's middle stands for all of it).
    /// `followsFace`: Follow face moves the frame with the face, so the zoom grows from the middle.
    static func make(placement: FramePlacement, face: FaceZoomFocus?, followsFace: Bool, at time: TimeInterval) -> ZoomAnchor {
        var anchor = ZoomAnchor()
        let frame = placement.crop.size
        guard frame.width > 0, frame.height > 0, placement.uprightSize.width > 0 else { return anchor }
        let across = placement.recordingSize(forVideoWidth: 1).width * placement.uprightSize.width
        let aspect = frame.width / frame.height
        anchor.resolutionLimit = (aspect <= 1 ? across : across / aspect) / minimumPixels
        guard let face, !followsFace else { return anchor }
        let point = placement.videoPoint(for: face.center, at: time)
        // A face Format's crop leaves out (or at its very edge) isn't grown toward.
        guard (0.05...0.95).contains(point.x), (0.05...0.95).contains(point.y) else { return anchor }
        anchor.pivot = point
        anchor.head = placement.videoRect(for: face.head, at: time)
        return anchor
    }
}
