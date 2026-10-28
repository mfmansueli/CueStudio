//
//  TextManipulation.swift
//  Cue Studio
//

import UIKit
import Foundation

/// A text a gesture on the preview is moving, resizing, turning or making wider: how it was when the gesture began, how far
/// the gesture has taken it, and its picture. The video leaves the text out meanwhile (`OverlaysViewModel.beginOverlayDrag`),
/// so the picture is the only copy; it is drawn once and only moved, scaled and turned, so the fingers never wait for the
/// text to be laid out again (a side tab is the exception: its lines break anew).
struct TextManipulation {
    let id: UUID
    /// This gesture: a picture drawn for an earlier one never lands on it (`TextPictureDrawer`).
    let gesture = UUID()
    let grip: TextGrip
    /// Its box's middle on the preview when the gesture began.
    let center: CGPoint
    /// Its box on the preview then, its keyframe's scale included.
    let box: CGSize
    /// Its turn then, in radians, clockwise (a graphic's own turn for a graphic).
    let rotation: Double
    /// Its keyframe's scale at the playhead (1 without keyframes): the picture is drawn at the text's own size.
    let shownScale: Double
    /// How opaque it shows at the playhead.
    let opacity: Double
    /// Its longest line when the gesture began, in points on the design's frame (a side tab's start).
    let lineWidth: Double

    /// Moved since, in points on the preview (stuck to the middle near it).
    var offset: CGSize = .zero
    /// Times as big (within its limits).
    var factor: Double = 1
    /// Turned since (stuck to straight near it).
    var turn: Double = 0
    /// A side tab: its lines' new length, in points on the design's frame.
    var newLineWidth: Double?
    /// Its picture and how many pixels per point of the preview it was drawn at (at the text's own size).
    var drawing: TextOverlayRenderer.Drawing?
    var pixels: CGFloat = 1
    /// A sharper picture being drawn away from the main thread, its pixels per point.
    var asked: CGFloat?
    /// Its turn is stuck to straight now, and its middle to the frame's middle lines.
    var turnSnapped = false
    var guides: (vertical: Bool, horizontal: Bool) = (false, false)

    /// Its box's middle now.
    var currentCenter: CGPoint { CGPoint(x: center.x + offset.width, y: center.y + offset.height) }

    /// Its turn now.
    var currentRotation: Double { rotation + turn }

    /// Its box on the preview now: grown by the gesture, or as the side tab laid it out again.
    var currentBox: CGSize {
        if grip.isSide, let drawing {
            let points = CGFloat(shownScale) / max(0.001, pixels)
            return CGSize(width: drawing.box.width * points, height: drawing.box.height * points)
        }
        return CGSize(width: box.width * CGFloat(factor), height: box.height * CGFloat(factor))
    }

    /// The picture's size on the preview, the room around the box its shadow or effect draws in included.
    var pictureSize: CGSize {
        guard let drawing else { return currentBox }
        let points = CGFloat(shownScale * (grip.isSide ? 1 : factor)) / max(0.001, pixels)
        return CGSize(width: drawing.image.size.width * points, height: drawing.image.size.height * points)
    }

    /// A side tab: how far the box's middle has moved so the other side stays where it was (half the width it gained, along
    /// the text's own line).
    var sideHeldOffset: CGSize {
        let grown = (currentBox.width - box.width) / 2 * (grip == .trailing ? 1 : -1)
        return CGSize(width: grown * CGFloat(cos(rotation)), height: grown * CGFloat(sin(rotation)))
    }

    /// The picture's sharpness: drawn again bigger once it shows this much bigger than it was drawn (or is being drawn).
    func needsSharperPicture(displayScale: CGFloat) -> Bool {
        CGFloat(shownScale * factor) * displayScale > max(pixels, asked ?? 0) * 1.35
    }
}
