//
//  FontRemoval.swift
//  Cue Studio
//

import Foundation

/// Takes an imported family out of the pickers (`CustomFontStore.remove`) and says so with Undo; videos, drafts and styles that
/// use it keep drawing in it. One wording wherever a font is removed: Brand's list, and My fonts in the editor and the cover.
@MainActor
enum FontRemoval {
    static func remove(_ name: String, from fonts: CustomFontStore, toast: ToastService) {
        guard let removed = fonts.remove(name) else { return }
        Haptics.light()
        toast.show(
            String(localized: "\(name) removed · videos that use it keep it"),
            action: ToastAction(title: String(localized: "Undo")) { [fonts] in fonts.restore(removed) }
        )
    }
}
