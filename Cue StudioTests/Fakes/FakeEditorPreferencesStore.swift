//
//  FakeEditorPreferencesStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Quick edit's switches in memory, so tests never write the simulator's defaults.
@MainActor
final class FakeEditorPreferencesStore: EditorPreferencesStoring {
    var showsNarrationScript: Bool
    var narrationScriptSpeed: Double?
    var lowPowerNoticeShownAt: Date?

    init(showsNarrationScript: Bool = true, narrationScriptSpeed: Double? = nil) {
        self.showsNarrationScript = showsNarrationScript
        self.narrationScriptSpeed = narrationScriptSpeed
    }
}
