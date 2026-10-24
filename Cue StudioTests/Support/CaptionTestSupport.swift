//
//  CaptionTestSupport.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

extension FrameOverlay {
    /// The word lit in this state, however the captions light it (before motion: `emphasis`; with motion: `markup`).
    var litWord: Int? { lazyText?.emphasis?.index ?? lazyText?.markup?.lit }
}

extension CaptionSettings {
    /// `theme` as an edit saved before motion has it: the complete reading (or the first), played by `captionAnimation`.
    static func savedBeforeMotion(_ theme: CaptionTheme = .cue, version: Int? = 2) -> CaptionSettings {
        var settings = CaptionSettings(theme: theme)
        settings.styleVersion = version
        settings.motion = nil
        let spec = settings.spec
        settings.followsWords = spec.animation.followsWords
        return settings
    }
}
