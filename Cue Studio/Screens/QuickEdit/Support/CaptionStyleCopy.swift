//
//  CaptionStyleCopy.swift
//  Cue Studio
//

import Foundation

/// Text style › "Apply this style to captions": a text's look copied onto the captions, once. Only
/// how the lines look changes (font, weight, letter spacing, case, colors, fill, shadow, outline and
/// glow). What they say, when, their translations, whether they show, where they sit, how big they
/// are and how they come and go stay as they were; no other text is touched, and nothing links the
/// text and the captions afterwards (changing the text again leaves the captions alone).
///
/// Captions in the collection keep it: the look goes in `CaptionSettings.customLook`, so their place,
/// safe area, size, highlight and reveal are still the collection's. Captions from before the
/// collection take it as their type look (`TakeEdit.captionLook`), which already draws every reveal.
nonisolated enum CaptionStyleCopy {
    /// What the captions look like now, which the copy replaces.
    enum Replaced: Equatable, Sendable {
        /// A preset, by the name Caption style shows ("Cue").
        case preset(String)
        /// A look of their own: copied from a text before, or an older version's style.
        case custom
    }

    /// The text's look as the captions': all of it but its size and its height on the frame (the
    /// captions keep theirs).
    static func look(from text: TextOverlay) -> TextLook {
        var look = TextLook(of: text)
        look.sizeScale = 1
        look.verticalOffset = 0
        return look
    }

    static func replaced(in edit: TakeEdit) -> Replaced {
        if let settings = edit.captionCollection {
            return settings.customLook == nil ? .preset(settings.theme.label) : .custom
        }
        if edit.captionLook != nil, let preset = edit.captionPreset { return .preset(preset.label) }
        return .custom
    }

    /// The color the said word will light in when the captions' own would vanish on `look` (a yellow
    /// title copied onto captions that light the word in yellow); nil when it stays. Only the
    /// collection has a highlight color to keep.
    static func changedHighlight(in edit: TakeEdit, for look: TextLook) -> CaptionAccent? {
        guard let current = edit.captionCollection?.highlightColor else { return nil }
        let shown = current.standingOut(on: look)
        return shown == current ? nil : shown
    }

    /// The copy, on what undo keeps: one step, with nothing else changed.
    static func apply(_ look: TextLook, to snapshot: inout EditSnapshot) {
        guard var settings = snapshot.captionCollection else {
            var legacy = look
            // Captions from before the collection keep their size too.
            legacy.sizeScale = snapshot.captionLook?.sizeScale ?? 1
            snapshot.captionLook = legacy
            snapshot.captionPreset = nil
            return
        }
        let current = settings.highlightColor
        settings.customLook = look
        let shown = current.standingOut(on: look)
        if shown != current { settings.accent = shown }
        snapshot.captionCollection = settings
    }
}
