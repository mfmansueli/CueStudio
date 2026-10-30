//
//  CaptionsViewModel+WornTheme.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
extension CaptionsViewModel {
    /// The style of the catalogue the captions wear as it is; nil while they wear it changed (Adjust, a text's look copied
    /// onto them, set by an older version) or the old caption style.
    var captionTheme: CaptionTheme? {
        guard let settings = edit.captionCollection, settings.customLook == nil, settings.changedLookCount == 0 else { return nil }
        return settings.theme
    }
}
