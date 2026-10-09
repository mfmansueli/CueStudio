//
//  QuickEditViewModel+CaptionStyleCopy.swift
//  Cue Studio
//

import Foundation

/// Text style › "Apply this style to captions": asks first, saying what the captions lose (their
/// preset, or the look they had) and what stays, then copies the picked text's look onto them as one
/// undo step (`CaptionStyleCopy`). Once: the text and the captions aren't linked afterwards, and no
/// other text changes.
extension QuickEditViewModel {
    /// The action shows for a picked text when the take has captions to style.
    var canCopyStyleToCaptions: Bool {
        selectedText != nil && !edit.captions.isEmpty
    }

    /// The text being asked about.
    var captionStyleCopySource: TextOverlay? {
        captionStyleCopySourceID.flatMap { id in edit.texts.first { $0.id == id } }
    }

    /// "Apply this style to captions": the question, about the picked text.
    func askToCopyStyleToCaptions() {
        guard isReady, canCopyStyleToCaptions, let id = selectedTextID else { return }
        player.pause()
        captionStyleCopySourceID = id
    }

    /// What the copy does: what it replaces, what stays, and the highlight when it has to change.
    var captionStyleCopyMessage: String {
        guard let text = captionStyleCopySource else { return "" }
        var parts: [String] = []
        switch CaptionStyleCopy.replaced(in: edit) {
        case .preset(let name):
            parts.append(String(localized: "Your captions use the \(name) preset. This text’s font, colors, background, shadow and glow replace it."))
        case .custom:
            parts.append(String(localized: "This text’s font, colors, background, shadow and glow replace your captions’ current style."))
        }
        parts.append(String(localized: "Words, timing, translations, position, size and how lines appear stay the same. Other texts don’t change."))
        if let accent = CaptionStyleCopy.changedHighlight(in: edit, for: CaptionStyleCopy.look(from: text)) {
            parts.append(String(localized: "The highlight color changes so the word being said stands out: \(accent.label)."))
        }
        return parts.joined(separator: "\n\n")
    }

    /// Apply: the text's look on the captions, one undo step (Undo in the toast takes it back).
    func copyStyleToCaptions() {
        defer { captionStyleCopySourceID = nil }
        guard isReady, let text = captionStyleCopySource, !edit.captions.isEmpty else { return }
        let look = CaptionStyleCopy.look(from: text)
        change { CaptionStyleCopy.apply(look, to: &$0) }
        toast.show(
            String(localized: "Captions use this style"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
        )
    }

    /// Cancel: nothing changes.
    func cancelCopyingStyleToCaptions() {
        captionStyleCopySourceID = nil
    }
}
