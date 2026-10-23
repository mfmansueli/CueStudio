//
//  QuickEditViewModel+Lock.swift
//  Cue Studio
//

import Foundation

/// Lock (Edits' clip lock): a text, photo or video, music or voice-over lined up where it belongs is locked in place on the
/// timeline, so a drag meant for something else can't move or trim it. It is still picked, styled and deleted on purpose.
extension QuickEditViewModel {
    /// The layer the toolbar's Lock works on.
    private var lockableID: UUID? {
        selection?.textID ?? selection?.mediaID ?? selection?.musicID ?? selection?.voiceOverID
    }

    var selectionIsLocked: Bool {
        lockableID.map { edit.lockedLayers.contains($0) } ?? false
    }

    /// Locks the picked layer, or unlocks it.
    func toggleLockOfSelection() {
        guard let id = lockableID else { return }
        if edit.lockedLayers.contains(id) {
            edit.lockedLayers.remove(id)
            toast.show(String(localized: "Unlocked · It moves and trims again"))
        } else {
            edit.lockedLayers.insert(id)
            toast.show(String(localized: "Locked in place on the timeline"))
        }
        Haptics.selection()
    }
}
