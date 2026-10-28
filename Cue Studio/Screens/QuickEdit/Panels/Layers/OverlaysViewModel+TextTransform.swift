//
//  OverlaysViewModel+TextTransform.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A text handled on the preview: moved, resized and turned with one or two fingers (or its corner handle), or made wider or
/// narrower with its side handles. While the fingers move, the editor only moves a picture of the text; when they lift, the
/// change lands as one undo step, inside the same limits the picture kept to, so nothing jumps. Resizing a text as a whole
/// gives it a block of its own (`TextBlock`): its lines break where they did, everything it draws grows with it. With
/// keyframes, it's the keyframe at the playhead that moves, grows and turns.
extension OverlaysViewModel {
    /// A text turns to a quarter turn when it comes this close to one (4°).
    nonisolated static let rotationSnap = 4 * Double.pi / 180

    /// How the text is turned on the preview at the playhead (its keyframes' turn when they move it). A graphic draws its own
    /// turn (`TextGraphic.rotation`), so its box stays upright.
    func rotation(ofText text: TextOverlay) -> Double {
        guard text.graphic == nil else { return 0 }
        return text.keyframes.isEmpty ? text.rotation : motionState(of: .text(text.id)).rotation
    }

    /// The share of `factor` the text can take: as big as its sizes allow (or its keyframe's scales). The same limit while
    /// the fingers move as when they lift.
    func allowedScale(_ factor: Double, forText text: TextOverlay) -> Double {
        guard factor.isFinite, factor > 0 else { return 1 }
        if text.keyframes.isEmpty {
            let size = min(max(text.size * factor, TextOverlay.sizeRange.lowerBound), TextOverlay.sizeRange.upperBound)
            return size / max(1, text.size)
        }
        let current = max(0.001, motionState(of: .text(text.id)).scale)
        let range = OverlayKeyframe.scaleRange
        return min(max(current * factor, range.lowerBound), range.upperBound) / current
    }

    /// A turn stuck to the nearest quarter turn when it comes within `rotationSnap` of it.
    nonisolated static func snappedRotation(_ rotation: Double) -> (rotation: Double, snapped: Bool) {
        let quarter = Double.pi / 2
        let nearest = (rotation / quarter).rounded() * quarter
        guard abs(rotation - nearest) < rotationSnap else { return (rotation, false) }
        return (nearest, true)
    }

    /// A turn between -180° and 180°.
    nonisolated static func normalizedRotation(_ rotation: Double) -> Double {
        guard rotation.isFinite else { return 0 }
        let turned = remainder(rotation, 2 * .pi)
        return abs(turned) < 0.000_1 ? 0 : turned
    }

    /// The fingers lifted: the text moved to `center` (unit coordinates), `factor` times as big and turned to `rotation`
    /// (radians, clockwise), one undo step. With keyframes, its keyframe at the playhead takes it.
    func transformText(_ id: UUID, center: OverlayPoint, factor: Double, rotation: Double) {
        guard let text = edit.texts.first(where: { $0.id == id }) else { return }
        // Clamped from the factor asked for, so a size at its limit is the limit exactly.
        let grows = abs(allowedScale(factor, forText: text) - 1) > 0.000_1
        let turn = Self.normalizedRotation(rotation)
        beginChange()
        defer { endChange() }
        if !text.keyframes.isEmpty {
            setAtPlayhead(of: .text(id)) { keyframe in
                keyframe.center = center.clamped
                if grows {
                    let range = OverlayKeyframe.scaleRange
                    keyframe.scale = min(max(keyframe.scale * factor, range.lowerBound), range.upperBound)
                }
                if text.graphic == nil { keyframe.rotation = turn }
            }
            if text.graphic != nil { updateText(id) { $0.graphic?.rotation = turn } }
            return
        }
        updateText(id) { text in
            let before = text
            text.center = center.clamped
            if grows {
                if text.block == nil, text.graphic == nil {
                    // From now on its lines are as long as they are, at its size: twice as big is the same text, twice as big.
                    text.block = TextBlock(width: TextOverlayRenderer.currentLineWidth(of: text), size: text.size)
                }
                text.size = min(max(text.size * factor, TextOverlay.sizeRange.lowerBound), TextOverlay.sizeRange.upperBound)
                text.customized.insert(.size)
            }
            if text.graphic != nil {
                text.graphic?.rotation = turn
            } else {
                text.rotation = turn
            }
            if text.center != before.center { text.customized.insert(.position) }
        }
    }

    /// A side handle let go: the text's lines as long as `width` (points on the design's frame), its box centered on
    /// `center`; one undo step. Lines break again; its size stays.
    func setTextBlock(_ id: UUID, width: Double, center: OverlayPoint) {
        guard let text = edit.texts.first(where: { $0.id == id }), text.graphic == nil else { return }
        beginChange()
        defer { endChange() }
        updateText(id) { text in
            text.block = TextBlock(width: width, size: text.size)
            if text.keyframes.isEmpty {
                text.center = center.clamped
                text.customized.insert(.position)
            }
        }
        if !text.keyframes.isEmpty { setAtPlayhead(of: .text(id)) { $0.center = center.clamped } }
    }

    /// `text` with its lines as long as `width` (points on the design's frame): what the side handle shows while it moves.
    nonisolated static func text(_ text: TextOverlay, withLineWidth width: Double) -> TextOverlay {
        var changed = text
        changed.block = TextBlock(width: width, size: text.size)
        return changed
    }

    /// Text style's Turn: the picked text's turn at the playhead, in degrees.
    var pickedTextTurnDegrees: Double {
        guard let text = selectedText else { return 0 }
        return (Self.normalizedRotation(rotation(ofText: text)) * 180 / .pi).rounded()
    }

    /// Text style's Turn slider: the picked text turned to `degrees` (with keyframes, its keyframe at the playhead). A drag of
    /// the slider is one undo step (`beginPanelChange`).
    func setTextTurn(degrees: Double) {
        guard let text = selectedText, text.graphic == nil else { return }
        let turn = Self.normalizedRotation(degrees * .pi / 180)
        if text.keyframes.isEmpty {
            updateText(text.id, key: "textTurn.\(text.id)") { $0.rotation = turn }
        } else {
            setAtPlayhead(of: .text(text.id)) { $0.rotation = turn }
        }
    }

    /// The text as the preview shows it at the playhead, drawn `pixels` pixels per point on a preview `width` points wide (its
    /// effect where it is in its motion): the picture that follows the fingers while the video leaves the text out.
    func drawing(ofText text: TextOverlay, width: CGFloat, pixels: CGFloat) -> TextOverlayRenderer.Drawing? {
        drawingWork(ofText: text, width: width, pixels: pixels)()
    }

    /// `drawing(ofText:)` as work that can be done away from the main thread (an effect painted anew takes 20 to 80 ms).
    func drawingWork(ofText text: TextOverlay, width: CGFloat, pixels: CGFloat) -> @Sendable () -> TextOverlayRenderer.Drawing? {
        let time = text.playsEffectMotion ? localTime(of: .text(text.id)) : nil
        let length = editedSpan(ofText: text.id)?.duration ?? 0
        let frameWidth = width * pixels
        return { TextOverlayRenderer.drawing(for: text, frameWidth: frameWidth, time: time, length: length) }
    }
}
