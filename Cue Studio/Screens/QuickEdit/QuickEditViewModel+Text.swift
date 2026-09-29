//
//  QuickEditViewModel+Text.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import UIKit

/// Text: titles, subtitles, hooks and callouts over the video, in the project's style (Clean
/// until one is picked). Added at the playhead for the role's length, then written, restyled,
/// dragged on the preview and moved or stretched on the text track. Every change is an undo step;
/// a drag or the text sheet is one.
extension QuickEditViewModel {
    var selectedText: TextOverlay? {
        selectedTextID.flatMap { id in edit.texts.first { $0.id == id } }
    }

    var editingText: TextOverlay? {
        editingTextID.flatMap { id in edit.texts.first { $0.id == id } }
    }

    /// Adds a text at the playhead, selects it and opens it for writing.
    func addText(_ role: TextOverlayRole) {
        guard isReady else { return }
        player.pause()
        let span = placement(at: player.currentTime, length: role.defaultDuration)
        let text = TextOverlay(role: role, style: edit.textStyle, span: edit.timeline.sourceSpan(forEdited: span))
        change { $0.texts.append(text) }
        selectedTextID = text.id
        editingTextID = text.id
    }

    func selectText(_ id: UUID?) {
        selectedTextID = selectedTextID == id ? nil : id
        if let id, let span = editedSpan(ofText: id), !span.contains(player.currentTime) {
            // Shows it on the preview.
            player.pause()
            player.seek(to: span.start)
        }
    }

    func updateText(_ id: UUID, _ update: (inout TextOverlay) -> Void) {
        change { snapshot in
            guard let index = snapshot.texts.firstIndex(where: { $0.id == id }) else { return }
            update(&snapshot.texts[index])
        }
    }

    func deleteText(_ id: UUID) {
        change { $0.texts.removeAll { $0.id == id } }
        if editingTextID == id { editingTextID = nil }
        toast.show(String(localized: "Text deleted"))
    }

    /// A quick style for one text: how it looks and where it sits, not what it says.
    func applyStyle(_ style: CreatorStyle, toText id: UUID) {
        updateText(id) { style.apply(to: &$0) }
    }

    /// Where the text plays (edited seconds); nil when none of it does.
    func editedSpan(ofText id: UUID) -> TimeSpan? {
        edit.texts.first { $0.id == id }.flatMap { edit.timeline.editedSpan(forSource: $0.span) }
    }

    /// Texts showing at the playhead, for the preview's handles.
    var visibleTexts: [TextOverlay] {
        let time = player.currentTime
        return edit.texts.filter { text in
            guard let span = edit.timeline.editedSpan(forSource: text.span) else { return false }
            return span.contains(time) || (abs(time - edit.editedDuration) < 0.001 && abs(span.end - time) < 0.001)
        }
    }

    /// The text's box on a preview of `size` (from the top left), measured like the export draws
    /// it.
    func frame(ofText text: TextOverlay, in size: CGSize) -> CGRect {
        let box = TextOverlayRenderer.size(for: text, frameWidth: size.width)
        let center = text.center.clamped
        return CGRect(
            x: CGFloat(center.x) * size.width - box.width / 2,
            y: CGFloat(center.y) * size.height - box.height / 2,
            width: box.width, height: box.height
        )
    }

    /// The text as the export draws it, on a preview `width` points wide: what follows the finger
    /// while it's dragged.
    func image(ofText text: TextOverlay, width: CGFloat) -> UIImage? {
        TextOverlayRenderer.image(for: text, frameWidth: width)
    }

    /// A stretch of `length` seconds from `start`, inside the edit: moved back when it would run
    /// past the end.
    func placement(at start: TimeInterval, length: TimeInterval) -> TimeSpan {
        let total = edit.editedDuration
        let length = min(length, total)
        let from = max(0, min(start, total - length))
        return TimeSpan(start: from, end: from + length)
    }
}
