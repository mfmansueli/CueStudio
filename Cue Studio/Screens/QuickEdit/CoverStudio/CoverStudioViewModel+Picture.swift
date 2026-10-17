//
//  CoverStudioViewModel+Picture.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import PhotosUI
import SwiftUI

/// The Picture step: a frame of the edit (picked on the strip, then frame by frame) or a photo, zoomed and moved with two
/// fingers or one on the canvas, back to filling the cover with Reset. A before/after has the same for its after half, and a
/// divider to drag.
extension CoverStudioViewModel {
    /// The frame the cover (or the after half) shows, where it plays in the edit; nil for a photo or a part that was cut.
    var pictureEditedTime: TimeInterval? {
        let source = editsSecondPicture ? composition.activeSplit?.source : cover.source
        guard let frame = source?.frame else { return nil }
        return edit.editedTime(of: frame)
    }

    var pictureIsPhoto: Bool {
        let source = editsSecondPicture ? composition.activeSplit?.source : cover.source
        if case .photo? = source { return true }
        return false
    }

    /// A frame picked on the strip (edited seconds): one undo step per lift of the finger.
    func useFrame(atEdited time: TimeInterval) {
        let clamped = min(max(0, time), edit.editedDuration)
        if !editsSecondPicture { lastFrameTime = clamped }
        setSource(.clipFrame(edit.coverFrame(atEdited: clamped)))
    }

    /// One frame earlier or later (`frames` at the recording's rate), for the exact moment.
    func stepFrame(by frames: Int, frameRate: Double) {
        let time = (pictureEditedTime ?? 0) + Double(frames) / max(1, frameRate)
        useFrame(atEdited: time)
    }

    /// A photo from the library: copied in, then used.
    func usePhoto(_ item: PhotosPickerItem) async {
        guard !isImporting else { return }
        setImporting(true)
        defer { setImporting(false) }
        do {
            let imported = try await importing.importMedia(item)
            remember(imported: imported.fileName)
            guard imported.kind == .photo else {
                notice = String(localized: "Pick a photo for the cover")
                return
            }
            setSource(.photo(fileName: imported.fileName))
        } catch {
            notice = error.localizedDescription
        }
    }

    private func setSource(_ source: CoverSource) {
        if editsSecondPicture {
            changeComposition { composition in
                composition.split?.source = source
                composition.split?.framing = CoverFraming()
            }
        } else {
            change { cover in
                cover.source = source
            }
        }
    }

    /// The framing the Picture step works on.
    var framing: CoverFraming {
        editsSecondPicture ? (composition.activeSplit?.framing ?? CoverFraming()) : composition.framing
    }

    /// A finger moved the picture by `translation` (canvas points, since the gesture began) on a canvas of `size`.
    func panPicture(from base: CoverFraming, by translation: CGSize, in size: CGSize) {
        guard let picture = pictureSize else { return }
        let frames = CoverCompositionRenderer.pictureFrames(composition, size: size)
        let frame = (editsSecondPicture ? frames.second : nil) ?? frames.main
        setFraming(base.moved(by: translation, picture: picture, frame: frame.size))
    }

    /// Two fingers zoomed the picture by `factor` since the gesture began.
    func zoomPicture(from base: CoverFraming, by factor: Double) {
        setFraming(base.zoomed(by: factor))
    }

    func setZoom(_ zoom: Double) {
        var framing = framing
        framing.zoom = zoom
        setFraming(framing.clamped)
    }

    /// Back to filling the cover, centered.
    func resetFraming() {
        setFraming(CoverFraming())
    }

    func setFraming(_ framing: CoverFraming) {
        changeComposition { composition in
            if editsSecondPicture { composition.split?.framing = framing } else { composition.framing = framing }
        }
    }

    /// The size of the picture being framed, in pixels.
    var pictureSize: CGSize? {
        pictureImageSize(second: editsSecondPicture)
    }

    // MARK: - Before / after

    /// The divider dragged to `position` (share of the width).
    func moveDivider(to position: Double) {
        changeComposition { composition in
            composition.split?.position = min(max(position, CoverSplit.positionRange.lowerBound), CoverSplit.positionRange.upperBound)
        }
    }

    func setSplitLabels(before: String? = nil, after: String? = nil) {
        changeComposition { composition in
            if let before { composition.split?.beforeLabel = before }
            if let after { composition.split?.afterLabel = after }
        }
    }

    func setShowsSplitLabels(_ shows: Bool) {
        changeComposition { $0.split?.showsLabels = shows }
    }
}
