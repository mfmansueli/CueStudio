//
//  CaptionsViewModel+MyStyle.swift
//  Cue Studio
//

import Foundation

/// The captions' "My style", like the texts' and the cover's: saved from Caption style, one tap puts it on every line, and the
/// next videos' captions start in it, so a creator's look carries from one video to the next without redoing it.
extension CaptionsViewModel {
    /// Keeps the captions' look now as "My style".
    func saveMyCaptionStyle() {
        guard let style = MyCaptionStyle(of: edit) else { return }
        styles.myCaptionStyle = style
        myCaptionStyle = style
        toast.show(String(localized: "Saved as My style"))
    }

    /// Every line in "My style", one undo step.
    func applyMyCaptionStyle() {
        guard isReady, let mine = myCaptionStyle, !captionsWearMyStyle else { return }
        let aspect = edit.aspect
        change { snapshot in
            let before = snapshot.captionCollection
            mine.apply(to: &snapshot)
            // A style saved before formats keeps the edit's format.
            if snapshot.captionCollection?.format == nil { snapshot.captionCollection?.format = before?.format }
            Self.refit(&snapshot, from: before, aspect: aspect)
        }
        previewCurrentCaptionLine()
        sayUndoable(String(localized: "My style on every line"))
    }

    /// The captions look like "My style" now.
    var captionsWearMyStyle: Bool {
        myCaptionStyle?.isWorn(by: edit) ?? false
    }

    /// New captions on a video whose captions were never styled start in "My style".
    func startsCaptionsInMyStyle(_ snapshot: inout EditSnapshot) {
        guard let mine = myCaptionStyle, edit.captions.isEmpty, var current = edit.captionCollection else { return }
        let fresh = CaptionSettings()
        current.safeMargins = fresh.safeMargins
        current.styleVersion = fresh.styleVersion
        // The format is how the lines are cut, not a look: an edit whose lines were deleted is still unstyled.
        current.format = fresh.format
        guard current == fresh else { return }
        mine.apply(to: &snapshot)
    }
}
