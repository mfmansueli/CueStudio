//
//  LookViewModel+CopyLook.swift
//  Cue Studio
//

import Foundation

/// "Copy look" and "Paste look" on clips: a picked clip's light and color, Skin, filter, background and zoom, pasted on another clip
/// or on every clip, all of it or only the parts picked (`CopiedClipLook`). One undo step per paste.
///
/// The first paste of a project asks in the sheet; the next ones repeat that choice where it fits (`PasteLookChoice.repeated`) and
/// open the sheet on it where it doesn't. Every paste's toast has Undo and Change: Change opens the sheet on the choice just used,
/// and what it pastes takes the place of that paste, so one Undo still goes back to before it. The look copied and the choice are
/// kept with the project, never as undo steps nor as a change to save (`remember`, `RememberedLook`): copy, leave and come back,
/// and the look is there, with no "Draft saved". A freeze frame takes a look like any clip; a photo over the video doesn't have
/// one yet, so Paste look there says where a look goes and changes nothing.
extension LookViewModel {
    /// Copies the picked clip's look.
    func copyClipLook() {
        guard let id = selection?.clipID, let segment = edit.timeline.segment(id: id) else { return }
        let copied = CopiedClipLook(of: segment, in: edit)
        remember { $0.copiedLook = copied }
        lastPaste = nil
        Haptics.selection()
        toast.show(String(localized: "Look copied · pick a clip and Paste look"))
    }

    /// The look Copy look took last in this project.
    var copiedLook: CopiedClipLook? { edit.copiedLook }

    var canPasteLook: Bool { copiedLook != nil }

    /// Paste look: the last choice again where it fits, else the sheet asks which parts and where.
    func askToPasteLook() {
        guard let copied = copiedLook else {
            toast.show(String(localized: "Copy a clip's look first"), kind: .problem)
            return
        }
        let clipID = selection?.clipID
        if let choice = edit.pasteLookChoice?.repeated(on: clipID, of: copied, in: edit) {
            paste(choice, on: clipID, replacing: nil, afterSheet: false)
            return
        }
        openPasteLook(on: edit.pasteLookChoice?.parts ?? Set(ClipLookPart.allCases), correcting: false)
    }

    /// Paste look on a photo over the video: nothing changes (no undo step, nothing to save), and it says where a look goes.
    func explainPasteOnPhoto() {
        toast.show(String(localized: "You can paste this look on video clips and freeze frames.", comment: "Paste look tapped on a photo over the video"))
    }

    /// Change, on a paste's toast: the sheet on the choice just used, to paste again in its place. When the edit changed since
    /// (another step was taken), the paste is no longer the last step and the sheet pastes as a new one.
    func changeLastPaste() {
        guard let made = lastPaste else { return }
        let correcting = made.after == snapshot
        if correcting, let clipID = made.clipID { selection = .clip(clipID) }
        openPasteLook(on: made.choice.parts, correcting: correcting)
    }

    /// The clip the sheet's "This clip" pastes on: the one the corrected paste went on, else the picked clip.
    var pasteLookClipID: UUID? {
        (correctsLastPaste ? lastPaste?.clipID : nil) ?? selection?.clipID
    }

    /// The sheet's Every clip and This clip: the parts on, on every clip or on one. One undo step.
    func pasteLook(on everyClip: Bool) {
        guard copiedLook != nil, !pastesLookParts.isEmpty else { return }
        let replacing = correctsLastPaste ? lastPaste : nil
        let clipID = everyClip ? nil : pasteLookClipID
        showsPasteLook = false
        paste(PasteLookChoice(parts: pastesLookParts, everyClip: everyClip), on: clipID, replacing: replacing, afterSheet: true)
    }

    func togglePasteLookPart(_ part: ClipLookPart) {
        if pastesLookParts.contains(part) { pastesLookParts.remove(part) } else { pastesLookParts.insert(part) }
    }

    // MARK: - Pasting

    private func openPasteLook(on parts: Set<ClipLookPart>, correcting: Bool) {
        pastesLookParts = parts
        showsPasteLook = true
        correctsLastPaste = correcting
    }

    /// Pastes `choice` on `clipID` (or every clip), remembers it, and says so with Undo and Change. `replacing`, the paste a Change
    /// corrects: it is undone first, so the edit ends with one paste, one step after where it was before it.
    private func paste(_ choice: PasteLookChoice, on clipID: UUID?, replacing made: PasteMade?, afterSheet: Bool) {
        guard let copied = copiedLook else { return }
        remember { $0.pasteLookChoice = choice }
        if let made, made.after == snapshot { session.document.undo() }
        lastPaste = nil
        let next = copied.pasted(choice.parts, everyClip: choice.everyClip, on: clipID, in: edit)
        // Nothing to change says so: a sheet that closes in silence reads as a button that didn't work.
        guard next != edit else {
            say(
                choice.everyClip ? String(localized: "Every clip already looks like this") : String(localized: "This clip already looks like this"),
                afterSheet: afterSheet, offersChange: false
            )
            return
        }
        commit(EditSnapshot(next))
        lastPaste = PasteMade(choice: choice, clipID: choice.everyClip ? nil : clipID, after: snapshot)
        let parts = choice.parts.count
        say(
            choice.everyClip ? String(localized: "Look pasted on every clip · \(parts) parts") : String(localized: "Look pasted · \(parts) parts"),
            afterSheet: afterSheet, offersChange: true
        )
    }

    /// The paste's toast (VoiceOver hears it), with Undo and Change when it pasted. After the sheet, once it has gone (about
    /// 0.35 s), so it's seen over the editor, not under a closing sheet.
    private func say(_ message: String, afterSheet: Bool, offersChange: Bool) {
        guard afterSheet else {
            showPasteToast(message, offersChange: offersChange)
            return
        }
        jobs.start(.notice) { [weak self] ticket in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, jobs.isCurrent(ticket) else { return }
            showPasteToast(message, offersChange: offersChange)
        }
    }

    private func showPasteToast(_ message: String, offersChange: Bool) {
        if offersChange {
            toast.show(message, action: undoAction, secondaryAction: changeAction)
        } else {
            toast.show(message)
        }
    }

    private var changeAction: ToastAction {
        ToastAction(title: String(localized: "Change")) { [weak self] in self?.changeLastPaste() }
    }
}
