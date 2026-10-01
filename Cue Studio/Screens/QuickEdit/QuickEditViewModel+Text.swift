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
        let pinned = edit.pin(span)
        var text = edit.newText(role, span: pinned.span)
        text.clipAnchor = pinned.anchor
        change { $0.texts.append(text) }
        selectedTextID = text.id
        editingTextID = text.id
    }

    /// Text menu › Title, Subtitle, Hook or Callout: adds it at the playhead, picks it and opens
    /// Text style with the keyboard up.
    func addStyledText(_ role: TextOverlayRole) {
        addText(role)
        editingTextID = nil
        toolMenu = nil
        textStyleScope = .selected
        panel = .textStyle
        focusesTextField = true
    }

    /// A copy of the text a little lower, picked.
    func duplicateText(_ id: UUID) {
        guard let original = edit.texts.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.center = OverlayPoint(x: original.center.x, y: min(0.9, original.center.y + 0.08)).clamped
        copy.keyframes = original.keyframes.map { keyframe in
            var moved = keyframe
            moved.id = UUID()
            moved.center = OverlayPoint(x: keyframe.center.x, y: min(0.9, keyframe.center.y + 0.08)).clamped
            return moved
        }
        change { $0.texts.append(copy) }
        selection = .text(copy.id)
        toast.show(String(localized: "Text duplicated"))
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
        Haptics.delete()
        if editingTextID == id { editingTextID = nil }
        toast.show(String(localized: "Text deleted"))
    }

    /// Where the text plays (edited seconds); nil when none of it does.
    func editedSpan(ofText id: UUID) -> TimeSpan? {
        edit.texts.first { $0.id == id }.flatMap { TakeEdit.editedSpan($0.span, anchor: $0.clipAnchor, in: edit.timeline) }
    }

    /// Texts showing at the playhead, for the preview's handles.
    var visibleTexts: [TextOverlay] {
        let time = player.currentTime
        return edit.texts.filter { text in
            guard let span = TakeEdit.editedSpan(text.span, anchor: text.clipAnchor, in: edit.timeline) else { return false }
            return span.contains(time) || (abs(time - edit.editedDuration) < 0.001 && abs(span.end - time) < 0.001)
        }
    }

    /// The text's box on a preview of `size` (from the top left), measured like the export draws
    /// it.
    func frame(ofText text: TextOverlay, in size: CGSize) -> CGRect {
        var box = TextOverlayRenderer.size(for: text, frameWidth: size.width)
        var center = text.center.clamped
        if !text.keyframes.isEmpty {
            // Where its keyframes have it at the playhead.
            let state = motionState(of: .text(text.id))
            center = state.center.clamped
            box = CGSize(width: box.width * CGFloat(state.scale), height: box.height * CGFloat(state.scale))
        }
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
