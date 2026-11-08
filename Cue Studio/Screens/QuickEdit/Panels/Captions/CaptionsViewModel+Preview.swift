//
//  CaptionsViewModel+Preview.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The caption on the preview: tap it to pick its line (again: Captions opens on it, keyboard up), drag it up or down to move
/// every caption, sticking to top, middle and bottom, and to the split screen's seam while one shows.
extension CaptionsViewModel {
    /// Where captions stick when dragged: top, middle and bottom, the same places Position puts them.
    static let captionStops: [Double] = CaptionPosition.allCases.map(\.verticalFraction)
    /// Captions stick to a stop within this share of the frame.
    static let captionSnap: Double = 0.03

    /// The caption showing at the playhead and its box on a preview of `size` (from the top left).
    func previewCaption(in size: CGSize) -> (id: UUID, frame: CGRect)? {
        guard edit.showsCaptions, size.width > 0 else { return nil }
        let time = player.currentTime
        guard let instance = captionMap.instance(at: time) else { return nil }
        var shown = edit
        // Only that line, measured the way the export draws it.
        shown.captions = edit.captions.filter { $0.id == instance.cueID }
        shown.captionTranslations = []
        let overlays = EditedComposition.captionOverlays(for: shown, frame: size)
        guard let overlay = overlays.first(where: { $0.span?.contains(time) ?? true }) ?? overlays.first else { return nil }
        let frame = CGRect(x: overlay.origin.x, y: size.height - overlay.origin.y - overlay.size.height, width: overlay.size.width, height: overlay.size.height)
        return (instance.cueID, frame)
    }

    /// A tap on the caption in the preview: picks its line; a second tap opens Captions on that line, keyboard up.
    func tapCaption(_ id: UUID) {
        guard isReady else { return }
        player.pause()
        if selection == .caption(id) {
            // A second tap: the line's words, with the keyboard up, to fix a word where it shows.
            panel = .captions
            focusesCaptionField = true
            return
        }
        Haptics.selection()
        let keepsPanel = panel == .captions || panel == .captionStyle
        selection = .caption(id)
        if !keepsPanel { panel = nil }
    }

    /// Where captions go when dragged to `y` (unit, from the top): stuck to the split screen's `seam` when one shows there, else
    /// to top, middle or bottom, when close.
    static func snappedCaption(_ y: Double, seam: Double? = nil) -> (y: Double, stop: Double?) {
        let clamped = min(max(y, 0.1), 0.9)
        if let seam, abs(seam - clamped) < captionSnap { return (seam, seam) }
        if let stop = captionStops.first(where: { abs($0 - clamped) < captionSnap }) { return (stop, stop) }
        return (clamped, nil)
    }

    /// Every caption moves up or down to `y` (unit, from the top). One undo step. While a split screen shows, the captions stick
    /// to its seam and sit on it again (`SplitScreen.captionsOnSeam`); dragged elsewhere, they go where the creator puts them,
    /// and a toast says so with the way back.
    func moveCaptions(toY y: Double) {
        let seam = splitSeamAtPlayhead
        let placed = Self.snappedCaption(y, seam: seam)
        if let seam, edit.captionCollection != nil {
            moveCaptions(to: placed.y, onSeam: placed.stop == seam)
            return
        }
        let placedY = placed.y
        if edit.captionCollection != nil {
            let before = edit.captionCollection?.center?.y ?? edit.captionPosition.verticalFraction
            updateCaptionSettings { settings in
                settings.center = OverlayPoint(x: settings.center?.x ?? 0.5, y: placedY)
            }
            // Lines in their own place stay there: said, with the way to bring them along.
            let own = captionsInOwnPlace
            if own > 0, abs(before - placedY) > 0.000_1 {
                toast.show(
                    String(localized: "\(own) lines keep their own place"),
                    action: ToastAction(title: String(localized: "Move them too")) { [weak self] in self?.placeEveryCaptionWithAll() }
                )
            }
        } else {
            let nearest = CaptionPosition.allCases.min { abs($0.verticalFraction - placedY) < abs($1.verticalFraction - placedY) } ?? .bottom
            change { $0.captionPosition = nearest }
        }
    }

    /// The captions dropped while a split screen shows: on its seam (the option on), or at `y`, off it, the rest of the video too.
    private func moveCaptions(to y: Double, onSeam: Bool) {
        let wasOnSeam = edit.splitScreen.captionsOnSeam
        if onSeam, wasOnSeam { return }
        changeEdit { edit in
            edit.splitScreen.captionsOnSeam = onSeam
            guard !onSeam else { return }
            let x = edit.captionCollection?.center?.x ?? 0.5
            edit.captionCollection?.center = OverlayPoint(x: x, y: y)
        }
        if onSeam {
            toast.show(String(localized: "Captions on the seam during the split screen"))
        } else if wasOnSeam {
            toast.show(
                String(localized: "Captions stay where you put them"),
                action: ToastAction(title: String(localized: "On the seam")) { [weak self] in self?.setCaptionsOnSeam(true) }
            )
        }
    }

    /// The captions' height on the frame (unit, from the top): on the split screen's seam while they sit there.
    var captionY: Double {
        seamAtPlayhead ?? edit.captionCollection?.center?.y ?? edit.captionPosition.verticalFraction
    }

    /// The seam the captions sit on at the playhead (`SplitScreen.captionsOnSeam`), if they do.
    private var seamAtPlayhead: Double? {
        let time = player.currentTime
        return EditedComposition.seamSpans(of: edit).first { $0.span.contains(time) }?.y
    }

    /// The split screen's seam at the playhead, the captions on it or not: where a dragged caption sticks.
    var splitSeamAtPlayhead: Double? {
        guard edit.captionCollection != nil else { return nil }
        let time = player.currentTime
        return EditedComposition.splitSeams(of: edit).first { $0.span.contains(time) }?.y
    }
}
