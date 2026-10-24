//
//  CaptionsViewModel+Preview.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The caption on the preview: tap it to pick its line (again: Captions opens on it, keyboard up), drag it up or down to move
/// every caption, sticking to top, middle and bottom.
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

    /// Where captions go when dragged to `y` (unit, from the top): stuck to top, middle or bottom
    /// when close.
    static func snappedCaption(_ y: Double) -> (y: Double, stop: Double?) {
        let clamped = min(max(y, 0.1), 0.9)
        if let stop = captionStops.first(where: { abs($0 - clamped) < captionSnap }) { return (stop, stop) }
        return (clamped, nil)
    }

    /// Every caption moves up or down to `y` (unit, from the top). One undo step.
    func moveCaptions(toY y: Double) {
        let placed = Self.snappedCaption(y).y
        if edit.captionCollection != nil {
            updateCaptionSettings { settings in
                settings.center = OverlayPoint(x: settings.center?.x ?? 0.5, y: placed)
            }
        } else {
            let nearest = CaptionPosition.allCases.min { abs($0.verticalFraction - placed) < abs($1.verticalFraction - placed) } ?? .bottom
            change { $0.captionPosition = nearest }
        }
    }

    /// The captions' height on the frame (unit, from the top).
    var captionY: Double {
        edit.captionCollection?.center?.y ?? edit.captionPosition.verticalFraction
    }
}
