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
    var timelineLanes: [UUID: TimelineLane] = [:]
    var newVideoKitTakes: Set<UUID> = []
    var rememberedLooks: [UUID: RememberedLook] = [:]

    init(showsNarrationScript: Bool = true, narrationScriptSpeed: Double? = nil) {
        self.showsNarrationScript = showsNarrationScript
        self.narrationScriptSpeed = narrationScriptSpeed
    }

    func timelineLane(forTake id: UUID) -> TimelineLane? {
        timelineLanes[id]
    }

    func setTimelineLane(_ lane: TimelineLane, forTake id: UUID) {
        timelineLanes[id] = lane
    }

    func newVideoKitOffered(forTake id: UUID) -> Bool {
        newVideoKitTakes.contains(id)
    }

    func markNewVideoKitOffered(forTake id: UUID) {
        newVideoKitTakes.insert(id)
    }

    func rememberedLook(forTake id: UUID) -> RememberedLook? {
        rememberedLooks[id]
    }

    func setRememberedLook(_ look: RememberedLook, forTake id: UUID) {
        rememberedLooks[id] = look.isEmpty ? nil : look
    }
}
