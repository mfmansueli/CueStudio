//
//  QuickEditViewModel+Lock.swift
//  Cue Studio
//

import Foundation

/// Lock (Edits' clip lock): a text, photo or video, music or voice-over lined up where it belongs is locked in place, on the
/// timeline (no handles, it doesn't move or trim) and on the preview (it doesn't move, resize or turn), so a drag meant for
/// something else can't shift it (`EditorPart+Lock`). It is still picked, styled and deleted on purpose, and locking is an
/// undo step.
extension QuickEditViewModel {
    var selectionIsLocked: Bool {
        selection?.lockableID.map(isLocked) ?? false
    }

    /// Locks the picked layer, or unlocks it.
    func toggleLockOfSelection() {
        guard let id = selection?.lockableID else { return }
        if isLocked(id) {
            unlock(id)
        } else {
            changeEdit { $0.lockedLayers.insert(id) }
            toast.show(String(localized: "Locked in place"))
            Haptics.selection()
        }
    }
}
