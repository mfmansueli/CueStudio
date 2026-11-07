//
//  BrandViewModel+KitDraft.swift
//  Cue Studio
//

import Foundation

/// A kit closed by accident keeps its changes (owner, canvas 2 R11, 07/11/2026): a swipe down keeps them as a draft that comes back
/// when the same kit opens again (a new kit's, when a new one is started); Save and Cancel end it, as the creator meant.
extension BrandViewModel {
    /// Opens `kit` to change, or its draft when one was left.
    func edit(_ kit: BrandKit) {
        if let draft = kitDraft, draft.id == kit.id || (kits.kit(kit.id) == nil && kits.kit(draft.id) == nil) {
            kitBeingEditedIsDraft = true
            kitBeingEdited = draft
        } else {
            kitBeingEditedIsDraft = false
            kitBeingEdited = kit
        }
    }

    /// The sheet closed on `kit` without Save or Cancel: kept when it differs from how it opened (or it already was a draft).
    func sheetClosed(on kit: BrandKit, openedWith start: BrandKit) {
        if kitBeingEditedIsDraft || kit != start { kitDraft = kit }
        kitBeingEdited = nil
        kitBeingEditedIsDraft = false
    }

    /// Cancel: the changes go, and so does any draft of this kit.
    func discardKitChanges() {
        kitDraft = nil
        kitBeingEdited = nil
        kitBeingEditedIsDraft = false
    }
}
