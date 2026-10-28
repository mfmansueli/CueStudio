//
//  EditedComposition+Texts.swift
//  Cue Studio
//

import Foundation

nonisolated extension EditedComposition {
    /// The edit's texts and where each plays in the drawing. In the editor's preview (`window`: where the edit as made plays
    /// in the drawing grown to the whole recording), a text that changes over its own time counts that time from where the
    /// edit as made shows it: one whose start or end was trimmed off starts or ends at the window's edge, as in the export,
    /// so its keyframes, its Motion and its effect's way in are where the export has them. Off the window it isn't drawn.
    static func shownTexts(of edit: TakeEdit, window: TimeSpan?) -> [(text: TextOverlay, span: TimeSpan)] {
        let texts = edit.editedTexts(in: edit.timeline)
        guard let window else { return texts }
        return texts.compactMap { text, span in
            guard text.changesOverItsTime else { return (text, span) }
            let shown = TimeSpan(start: max(span.start, window.start), end: min(span.end, window.end))
            return shown.duration > 0 ? (text, shown) : nil
        }
    }
}
