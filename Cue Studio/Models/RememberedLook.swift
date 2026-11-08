//
//  RememberedLook.swift
//  Cue Studio
//

import Foundation

/// What Copy look and Paste look remember in a project (`TakeEdit.copiedLook`, `.pasteLookChoice`): the look copied last and how
/// it was pasted last. It isn't a change to the video (owner, 08/11/2026): copying alone leaves no undo step, no unsaved change
/// and no "Draft saved", and is still there when the project opens again (kept per take, `EditorPreferencesStoring`).
nonisolated struct RememberedLook: Codable, Hashable, Sendable {
    var copiedLook: CopiedClipLook?
    var pasteLookChoice: PasteLookChoice?

    init(copiedLook: CopiedClipLook?, pasteLookChoice: PasteLookChoice?) {
        self.copiedLook = copiedLook
        self.pasteLookChoice = pasteLookChoice
    }

    init(of edit: TakeEdit) {
        self.init(copiedLook: edit.copiedLook, pasteLookChoice: edit.pasteLookChoice)
    }

    var isEmpty: Bool { copiedLook == nil && pasteLookChoice == nil }

    func apply(to edit: inout TakeEdit) {
        edit.copiedLook = copiedLook
        edit.pasteLookChoice = pasteLookChoice
    }
}

extension TakeEdit {
    /// The edit without what Copy and Paste look remember: what "changed" means for saving and drafts.
    var forgettingRememberedLook: TakeEdit {
        var edit = self
        RememberedLook(copiedLook: nil, pasteLookChoice: nil).apply(to: &edit)
        return edit
    }
}
