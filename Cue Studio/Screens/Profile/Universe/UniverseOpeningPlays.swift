//
//  UniverseOpeningPlays.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// Your universe builds itself as it opens (`UniverseOpening`); UI tests with no animations (`-uiTestFastAnimations`) see it in place.
    @Entry var playsUniverseOpening = true
}
