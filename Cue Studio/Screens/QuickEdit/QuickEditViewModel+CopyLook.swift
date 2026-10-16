//
//  QuickEditViewModel+CopyLook.swift
//  Cue Studio
//

import Foundation

/// "Copy look" and "Paste look" on clips: a picked clip's light and color, filter, background and zoom, pasted on another clip
/// or on every clip, all of it or only the parts picked (`CopiedClipLook`). One undo step per paste.
extension QuickEditViewModel {
    /// Copies the picked clip's look.
    func copyClipLook() {
        guard let id = selection?.clipID, let segment = edit.timeline.segment(id: id) else { return }
        copiedLook = CopiedClipLook(of: segment, in: edit)
        pastesLookParts = Set(ClipLookPart.allCases)
        Haptics.selection()
        toast.show(String(localized: "Look copied · pick a clip and Paste look"))
    }

    var canPasteLook: Bool { copiedLook != nil }

    /// Paste look: asks which parts and where.
    func askToPasteLook() {
        guard copiedLook != nil else {
            toast.show(String(localized: "Copy a clip's look first"))
            return
        }
        showsPasteLook = true
    }

    /// Pastes the picked parts on the picked clip, or on every clip. One undo step.
    func pasteLook(on everyClip: Bool) {
        guard let copied = copiedLook, !pastesLookParts.isEmpty else { return }
        let target = selection?.clipID
        showsPasteLook = false
        if everyClip {
            let next = copied.pastedEverywhere(pastesLookParts, in: edit)
            guard next != edit else { return }
            commit(EditSnapshot(next))
        } else {
            var timeline = edit.timeline
            for segment in timeline.segments where segment.id == target {
                timeline.replaceSegment(copied.pasted(pastesLookParts, on: segment, in: edit))
            }
            guard timeline != edit.timeline else { return }
            commit(timeline)
        }
        toast.show(everyClip ? String(localized: "Look pasted on every clip") : String(localized: "Look pasted"))
    }

    func togglePasteLookPart(_ part: ClipLookPart) {
        if pastesLookParts.contains(part) { pastesLookParts.remove(part) } else { pastesLookParts.insert(part) }
    }
}
