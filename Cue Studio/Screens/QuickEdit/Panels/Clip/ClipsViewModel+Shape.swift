//
//  ClipsViewModel+Shape.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Rotate, Mirror and Crop of the picked clip (`EditSegment.orientation`). Crop's panel shows the clip's whole picture, turned
/// and mirrored, fitted in the frame with the box over it (`showingWholePicture`, `ClipCropLayer`); the box keeps a shape
/// (9:16, 4:5, 1:1, 16:9) or none (Free), and Original takes it away. Each change is an undo step; a drag of the box is one.
extension ClipsViewModel {
    /// The picked clip's picture turned and mirrored, before the crop, for a recording `size` big.
    func turnedPictureSize(ofRecording size: CGSize) -> CGSize {
        ClipOrientation(quarterTurns: targetClip?.quarterTurns ?? 0).turnedSize(of: size)
    }

    /// Mirror: the picked clip flipped left to right; its crop keeps the same part of the picture.
    func toggleClipMirror() {
        updateClip { clip in
            clip.isMirrored.toggle()
            clip.crop = clip.crop?.mirrored
        }
    }

    /// Rotate: the picked clip a quarter turn clockwise. A box of a shape goes to the middle of the turned picture, a free one
    /// goes (it was drawn on the other way round).
    func rotateClip(recordingSize size: CGSize?) {
        updateClip { clip in
            clip.quarterTurns = (clip.quarterTurns + 1) % 4
            guard let crop = clip.crop else { return }
            if let ratio = crop.ratio, let size {
                clip.crop = ClipCrop.centered(ratio, in: ClipOrientation(quarterTurns: clip.quarterTurns).turnedSize(of: size))
            } else {
                clip.crop = nil
            }
        }
    }

    /// Original (no crop), or a box of `ratio` (nil: Free, the whole picture to start from), as big as it can be in the middle
    /// of the picked clip's picture (`size`, turned).
    func setClipCropShape(original: Bool, ratio: AspectRatio?, pictureSize size: CGSize) {
        updateClip { clip in
            clip.crop = original ? nil : ClipCrop.centered(ratio, in: size)
        }
    }

    /// A finger moving or pulling Crop's box.
    func setClipCrop(_ crop: ClipCrop) {
        updateClip { $0.crop = crop }
    }

    /// What the preview plays while Crop is open: the picked clip's whole picture, turned and mirrored but not cut nor zoomed nor
    /// animated, fitted in the frame, so the box is drawn over all of it. Moving the box then never redraws the video.
    func showingWholePicture(in edit: TakeEdit) -> TakeEdit {
        guard panel == .clipCrop, let id = targetClip?.id, var clip = edit.timeline.segments.first(where: { $0.id == id }) else { return edit }
        clip.crop = nil
        clip.zoom = nil
        clip.animationIn = nil
        clip.animationOut = nil
        var shown = edit
        _ = shown.timeline.replaceSegment(clip)
        shown.cropFit = .fit
        return shown
    }
}
