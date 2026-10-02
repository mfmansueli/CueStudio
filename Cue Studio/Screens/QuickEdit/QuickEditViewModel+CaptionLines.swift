//
//  QuickEditViewModel+CaptionLines.swift
//  Cue Studio
//

import Foundation

/// Working through the captions line by line (Previous, Next, Return on the keyboard) and
/// clearing them all at once. Every change is an undo step, and clearing says so with an Undo.
extension QuickEditViewModel {
    // MARK: - Line by line

    /// "Line 3 of 12": where the line is among the lines in the order they play.
    func captionPosition(of cueID: UUID) -> (number: Int, total: Int)? {
        let lines = captionListLines
        guard let index = lines.firstIndex(where: { $0.cueID == cueID }) else { return nil }
        return (index + 1, lines.count)
    }

    /// The line `step` places from `cueID` (−1 the one before, 1 the one after), if there is one.
    func neighborCaptionLine(of cueID: UUID, by step: Int) -> (line: CaptionCue, cueID: UUID)? {
        let lines = captionListLines
        guard let index = lines.firstIndex(where: { $0.cueID == cueID }), lines.indices.contains(index + step) else { return nil }
        return lines[index + step]
    }

    /// Picks the line before or after (the playhead goes there). `keepsTyping` keeps the keyboard
    /// up on the new line, so a whole take can be proofread by typing and pressing Return.
    /// False when there is no such line.
    @discardableResult
    func goToCaptionLine(from cueID: UUID, by step: Int, keepsTyping: Bool = false) -> Bool {
        guard let neighbor = neighborCaptionLine(of: cueID, by: step) else { return false }
        pickCaptionLine(neighbor.cueID, at: neighbor.line.start)
        if keepsTyping { focusesCaptionField = true }
        return true
    }

    // MARK: - Clearing

    /// Every line at once, without picking and deleting them one by one. The transcript of what
    /// was heard stays, so Auto captions can make them again; Undo brings them back.
    func deleteAllCaptions() {
        let count = edit.captions.count
        guard isReady, count > 0 else { return }
        if selection?.captionID != nil { selection = nil }
        editingCaptionID = nil
        change { $0.captions = [] }
        Haptics.delete()
        toast.show(
            count == 1 ? String(localized: "Line deleted") : String(localized: "\(count) lines deleted"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
        )
    }
}
