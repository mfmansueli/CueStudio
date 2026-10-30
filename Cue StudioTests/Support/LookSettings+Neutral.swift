//
//  LookSettings+Neutral.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

extension LookSettings {
    /// Nothing is changed: the frame is drawn as recorded.
    var isNeutral: Bool {
        var neutral = self
        neutral.version = LookSettings.currentVersion
        neutral.filterAmount = 1
        neutral.autoAmount = 1
        // Skin that draws nothing (a smoothing at 0 on the first engine, one from a newer Cue) is no change.
        if !skin.isOn { neutral.skin = SkinLook() }
        return neutral == LookSettings()
    }
}
