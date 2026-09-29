//
//  QuickEditViewModel+Style.swift
//  Cue Studio
//

import Foundation

/// Style: one look for the whole video. Sets every text, the captions' style, the filter and the
/// cover's title, and new texts start from it. One undo step.
extension QuickEditViewModel {
    func applyCreatorStyle(_ style: CreatorStyle) {
        guard isReady else { return }
        change { snapshot in
            snapshot.creatorStyle = style
            snapshot.captionStyle = style.captionStyle
            snapshot.filter = style.filter
            for index in snapshot.texts.indices { style.apply(to: &snapshot.texts[index]) }
            snapshot.cover?.style = style
        }
        toast.show(String(localized: "\(style.label) style applied"))
    }
}
