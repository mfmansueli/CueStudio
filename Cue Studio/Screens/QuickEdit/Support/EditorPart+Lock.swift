//
//  EditorPart+Lock.swift
//  Cue Studio
//

import Foundation

/// A locked layer (`TakeEdit.lockedLayers`: a text, photo or video, music or voice-over) keeps its place and size on the
/// timeline and on the preview. A finger that tries to move, resize or turn it leaves it where it is and the toast says so, with
/// Unlock right there (once a gesture); picking it by hand says the same once, when it becomes the picked item (tapping it again,
/// or the next tool on it, doesn't), so the creator never wonders why it doesn't follow the finger.
extension EditorPart {
    func isLocked(_ id: UUID) -> Bool {
        edit.lockedLayers.contains(id)
    }

    /// A gesture on the preview (or VoiceOver's Move and Bigger) is about to move `id`: true, and said, when it is locked.
    func refusesMoving(_ id: UUID) -> Bool {
        guard isLocked(id) else { return false }
        sayLocked(id, kind: .problem)
        return true
    }

    /// "Locked in place", with Unlock: when a locked layer is picked by hand (`kind` done) or a finger tried to move it (problem).
    func sayLocked(_ id: UUID, kind: ToastKind = .done) {
        toast.show(
            String(localized: "Locked in place"), kind: kind,
            action: ToastAction(title: String(localized: "Unlock")) { [weak self] in self?.unlock(id) }
        )
    }

    /// An item picked by hand on the timeline or the preview, `previous` the pick before it: a locked one says so, with Unlock,
    /// only as it becomes the picked item.
    func sayIfLocked(_ item: EditorSelection, previous: EditorSelection?) {
        guard previous != item, let id = item.lockableID, isLocked(id) else { return }
        sayLocked(id)
    }

    /// The layer moves and trims again (an undo step).
    func unlock(_ id: UUID) {
        guard isLocked(id) else { return }
        changeEdit { $0.lockedLayers.remove(id) }
        toast.show(String(localized: "Unlocked · It moves and trims again"))
        Haptics.selection()
    }
}
