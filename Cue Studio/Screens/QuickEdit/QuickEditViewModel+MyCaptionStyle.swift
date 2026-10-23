//
//  QuickEditViewModel+MyCaptionStyle.swift
//  Cue Studio
//

import Foundation

/// The captions' "My style", like the texts' and the cover's: saved from Caption style, one tap puts it on every line, and the
/// next videos' captions start in it, so a creator's look carries from one video to the next without redoing it.
extension QuickEditViewModel {
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
        change { mine.apply(to: &$0) }
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
        guard current == fresh else { return }
        mine.apply(to: &snapshot)
    }
}
