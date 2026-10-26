//
//  OverlaysViewModel+Mask.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Mask: only part of the picked photo or video shows (a rectangle with rounded corners, a circle or ellipse, the side of a
/// line, a band), with a soft edge, inverted when wanted (`MediaMask`). The mask lives on the media's own place, so the media's
/// moves, keyframes, Track and preset take it along. On the preview a drag moves the mask over a still picture, or (Mask ›
/// Picture) reframes the picture under a still mask (`pictureFraming`). With keyframes, a change to the mask lands on the
/// keyframe at the playhead, so the mask can move, grow or soften over time; the shape and Invert stay the same throughout.
/// A support of the split screen has its area for a shape: no mask there. Every change is an undo step; a drag or a slider is
/// one.
extension OverlaysViewModel {
    /// How far a VoiceOver nudge moves the mask, as a share of its place.
    static let maskStep = 0.05

    /// Why the picked photo or video can't have a mask, or nil when it can.
    func maskUnavailableReason(_ media: MediaOverlay) -> String? {
        media.layout == .split
            ? String(localized: "A split-screen area already has its shape · Show it as a window or full screen to use a mask")
            : nil
    }

    /// The edit's frame, in points that keep its shape (only proportions matter for a mask).
    var maskFrameSize: CGSize {
        let aspect = edit.aspect.widthOverHeight
        return CGSize(width: 1000 * aspect, height: 1000)
    }

    /// Width over height of the media's place (its window, or the whole frame).
    func placeAspect(of media: MediaOverlay) -> Double {
        let rect = MediaPlacement.rect(for: media, in: maskFrameSize)
        return rect.height > 0 ? Double(rect.width / rect.height) : 1
    }

    /// Where the picked media's mask is at the playhead (its keyframes', or the mask's own); nil without a mask.
    func maskPlacementAtPlayhead(of media: MediaOverlay) -> MaskPlacement? {
        guard let mask = media.mask else { return nil }
        if media.keyframes?.contains(where: { $0.mask != nil }) == true, localTime(of: .media(media.id)) != nil {
            return motionState(of: .media(media.id)).mask ?? mask.placement
        }
        return mask.placement
    }

    /// Whether a change to the mask lands on the keyframe at the playhead (the media moves by keyframes).
    func maskFollowsKeyframes(_ media: MediaOverlay) -> Bool {
        media.keyframes?.isEmpty == false
    }

    // MARK: - Shape

    /// Puts a mask of `shape` on the picked photo or video, or another shape in place of its own (keeping where it is), or
    /// takes it off (nil). One undo step.
    func setMaskShape(_ shape: MaskShape?) {
        guard let media = selectedMedia else { return }
        if let reason = maskUnavailableReason(media) {
            toast.show(reason, kind: .problem)
            return
        }
        guard let shape else {
            guard media.mask != nil else { return }
            updateMedia(media.id) { item in
                item.mask = nil
                // Its placements on keyframes go with it.
                item.keyframes = item.keyframes?.map { keyframe in
                    var keyframe = keyframe
                    keyframe.mask = nil
                    return keyframe
                }
            }
            sayUndoable(String(localized: "Mask removed"))
            return
        }
        guard media.mask?.shape != shape else { return }
        Haptics.selection()
        let aspect = placeAspect(of: media)
        updateMedia(media.id) { item in
            item.mask = item.mask.map { $0.reshaped(shape, onPlaceOfAspect: aspect) } ?? MediaMask.starting(shape, onPlaceOfAspect: aspect)
        }
    }

    func setMaskInverted(_ inverted: Bool) {
        guard let media = selectedMedia, media.mask != nil, media.mask?.inverted != inverted else { return }
        updateMedia(media.id) { $0.mask?.inverted = inverted }
    }

    // MARK: - Placement

    /// Changes where the picked media's mask is: on its keyframe at the playhead when the media moves by keyframes, else the
    /// mask itself. `key` joins a slider's changes into one undo step.
    func updateMaskPlacement(key: String? = nil, _ update: (inout MaskPlacement) -> Void) {
        guard let media = selectedMedia, let mask = media.mask else { return }
        let current = maskPlacementAtPlayhead(of: media) ?? mask.placement
        var next = current
        update(&next)
        next = next.clamped
        guard next != current else { return }
        if maskFollowsKeyframes(media), localTime(of: .media(media.id)) != nil {
            setAtPlayhead(of: .media(media.id)) { $0.mask = next }
        } else {
            change(key: key) { snapshot in
                guard let index = snapshot.media.firstIndex(where: { $0.id == media.id }) else { return }
                snapshot.media[index].mask?.placement = next
            }
        }
    }

    func setMaskFeather(_ feather: Double) {
        updateMaskPlacement(key: "maskFeather") { $0.feather = feather }
    }

    func setMaskCorners(_ corners: Double) {
        updateMaskPlacement(key: "maskCorners") { $0.corners = corners }
    }

    func setMaskRotation(_ degrees: Double) {
        updateMaskPlacement(key: "maskRotation") { $0.rotation = degrees }
    }

    /// VoiceOver and the steppers: the mask a step over (shares of its place).
    func nudgeMask(x: Double, y: Double) {
        updateMaskPlacement { placement in
            placement.center = OverlayPoint(x: placement.center.x + x, y: placement.center.y + y)
        }
    }

    /// The mask `factor` times as big, both ways (a band: thicker; a line has no size).
    func scaleMask(by factor: Double) {
        guard let shape = selectedMedia?.mask?.shape, shape != .line else { return }
        updateMaskPlacement { placement in
            if shape == .band {
                placement.height *= factor
            } else {
                placement.width *= factor
                placement.height *= factor
            }
        }
    }

    /// Back to where a new mask of its shape starts, keeping Invert; the picture filling its place again.
    func resetMask() {
        guard let media = selectedMedia, let mask = media.mask else { return }
        let fresh = MediaMask.starting(mask.shape, onPlaceOfAspect: placeAspect(of: media))
        updateMedia(media.id) { item in
            item.mask?.placement = fresh.placement
            item.pictureFraming = nil
            item.keyframes = item.keyframes?.map { keyframe in
                var keyframe = keyframe
                keyframe.mask = nil
                return keyframe
            }
        }
        sayUndoable(String(localized: "Mask reset"))
    }

    /// Whether the mask or the picture under it moved from where they start.
    var maskIsAdjusted: Bool {
        guard let media = selectedMedia, let mask = media.mask else { return false }
        let fresh = MediaMask.starting(mask.shape, onPlaceOfAspect: placeAspect(of: media))
        return mask.placement != fresh.placement || media.pictureFraming != nil || media.keyframes?.contains { $0.mask != nil } == true
    }

    // MARK: - The picture under it

    /// Mask › Picture: the picture moved under the mask by a drag of `translation` on a place of `placeSize` (points), as far
    /// as it still covers its place.
    func panMaskedPicture(by translation: CGSize, placeSize: CGSize) {
        guard let media = selectedMedia else { return }
        var framing = media.pictureFraming ?? AreaFraming()
        framing.fit = .fill
        let picture = CGSize(width: media.aspect * 1000, height: 1000)
        let moved = SplitPlacement.dragged(framing, content: picture, area: placeSize, by: translation)
        guard moved != framing else { return }
        updateMedia(media.id) { $0.pictureFraming = moved }
    }

    /// Mask › Picture: the picture `factor` times closer under the mask (never smaller than its place).
    func zoomMaskedPicture(by factor: Double) {
        guard let media = selectedMedia else { return }
        var framing = media.pictureFraming ?? AreaFraming()
        framing.fit = .fill
        framing.zoom = min(max(framing.clampedZoom * factor, AreaFraming.zoomRange.lowerBound), AreaFraming.zoomRange.upperBound)
        guard framing != media.pictureFraming else { return }
        updateMedia(media.id) { $0.pictureFraming = framing }
    }

    // MARK: - Compare

    /// Mask's ◐: the photo or video whole, without its mask, while it's on.
    var maskCompare: PanelCompare {
        PanelCompare(
            isOn: comparesWithoutMask, isEnabled: selectedMedia?.mask != nil, hint: String(localized: "Shows the photo or video without its mask"),
            identifier: "edit.compare.mask"
        ) { [weak self] isOn in
            guard let self, !isOn || selectedMedia?.mask != nil else { return }
            comparesWithoutMask = isOn
        }
    }

    /// `edit` as the preview plays it while Mask's ◐ is on: the picked media without its mask.
    func withoutComparedMask(_ edit: TakeEdit) -> TakeEdit {
        guard comparesWithoutMask, let id = selectedMediaID, let index = edit.media.firstIndex(where: { $0.id == id }) else { return edit }
        var shown = edit
        shown.media[index].mask = nil
        return shown
    }
}
