//
//  OverlaysViewModel+Picking.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Picking and moving what is laid on the preview. Up to three photos or videos can show at once: each has its handle, in the
/// order they are drawn, and a tap goes to the one on top under the finger; tapping again where several overlap goes to the next
/// one under it, so a photo half hidden by another is still reachable. Tapping the picked one alone opens its panel. While a
/// text or a photo or video is dragged, the video draws it nowhere (`draggedOverlay`) and the copy under the finger is the only
/// one, so it never shows twice.
extension OverlaysViewModel {
    /// The photos and videos showing at the playhead, bottom to top, as the video stacks them (`CueVideoCompositor`).
    var visibleMediaStack: [MediaOverlay] {
        let time = player.currentTime
        let shown = mediaBars.enumerated().filter { $0.element.span.contains(time) }
        let ordered = shown.compactMap { offset, bar in edit.media.first { $0.id == bar.id }.map { (media: $0, offset: offset) } }
        return ordered.sorted { ($0.media.stackOrder, $0.offset) < ($1.media.stackOrder, $1.offset) }.map(\.media)
    }

    /// The photos and videos in a window under `point` on a preview of `size`, top first.
    func mediaHits(at point: CGPoint, in size: CGSize) -> [UUID] {
        visibleMediaStack.reversed().filter { media in
            media.layout == .window && frame(ofMedia: media, in: size).insetBy(dx: -6, dy: -6).contains(point)
        }.map(\.id)
    }

    /// A tap on a photo or video in the preview: the top one under the finger; where several overlap and one of them is picked,
    /// the next one under it; the picked one alone opens its panel.
    func tapMedia(at point: CGPoint, in size: CGSize) {
        guard isReady else { return }
        let hits = mediaHits(at: point, in: size)
        guard let top = hits.first else { return }
        player.pause()
        if let current = selection?.mediaID, let index = hits.firstIndex(of: current) {
            guard hits.count > 1 else {
                panel = .media
                return
            }
            pickMedia(hits[(index + 1) % hits.count])
            return
        }
        pickMedia(top)
    }

    private func pickMedia(_ id: UUID) {
        Haptics.selection()
        let keepsPanel = panel == .media
        selection = .media(id)
        if !keepsPanel { panel = nil }
    }

    // MARK: - Dragging

    /// A finger started moving a text or a photo or video: the video stops drawing it until `endOverlayDrag`.
    func beginOverlayDrag(_ item: EditorSelection) {
        guard draggedOverlay != item else { return }
        draggedOverlay = item
        session.showPlayedEdit()
    }

    /// The finger lifted: the item is drawn by the video again, where the change put it. Call after the change.
    func endOverlayDrag() {
        guard draggedOverlay != nil else { return }
        draggedOverlay = nil
        session.showPlayedEdit()
    }

    /// `edit` without the item being dragged: a text left out, a photo or video kept (its track stays, so the picture doesn't
    /// blink) but fully transparent.
    func hidingDraggedOverlay(in edit: TakeEdit) -> TakeEdit {
        guard let dragged = draggedOverlay else { return edit }
        var shown = edit
        if let id = dragged.textID {
            shown.texts.removeAll { $0.id == id }
        } else if let id = dragged.mediaID, let index = shown.media.firstIndex(where: { $0.id == id }) {
            let center = shown.media[index].center
            shown.media[index].keyframes = [OverlayKeyframe(time: 0, center: center, opacity: 0)]
        }
        return shown
    }
}
