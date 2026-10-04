//
//  ScriptStrip.swift
//  Cue Studio
//

import Foundation

/// What the state strip on the script page says (v29 · 4.1): the state (READY, DRAFT or RECORDED), the format and how many cues,
/// and the one next step. Pure, so every state of 04 · F2 is tested.
nonisolated struct ScriptStrip: Equatable, Sendable {
    let state: ScriptState
    /// The script's format; nil says "Your script".
    let formatLabel: String?
    let cueCount: Int
    /// The number of the latest take, when the words changed after it ("CHANGED SINCE TAKE 3").
    let changedSinceTake: Int?
    /// The words were edited this visit and Done wasn't tapped.
    let isEdited: Bool
    let canShape: Bool

    init(
        script: Script, takes: [Take], hasAI: Bool, isEdited: Bool
    ) {
        state = script.state(takeCount: takes.count)
        formatLabel = script.type?.structure.label
        cueCount = CueParser.count(in: script.text)
        let latest = takes.max { $0.number < $1.number }
        // Editing a recorded script moves it on from its take even before the new version is saved.
        let changed = script.changedSince(latestTakeVersion: latest?.scriptVersion) || (isEdited && !takes.isEmpty)
        changedSinceTake = changed ? latest?.number : nil
        self.isEdited = isEdited
        canShape = hasAI && cueCount == 0 && !script.isEmpty
    }

    /// The mono line: "LIST · 4 CUES", "EDITED · TAP DONE", "CHANGED SINCE TAKE 3".
    var info: [String] {
        if state == .recorded, let take = changedSinceTake {
            return [String(localized: "Changed since take \(take)")]
        }
        if isEdited, state != .recorded {
            return [String(localized: "Edited"), String(localized: "Tap Done")]
        }
        return [formatLabel ?? String(localized: "Your script"), ScriptRowLine.cues(cueCount)]
    }

    /// The line is a signal (yellow) when the script has moved on from its take.
    var isSignal: Bool { state == .recorded && changedSinceTake != nil }

    /// DRAFT and READY have Done (a button for a draft, plain text once ready); a recorded script has none.
    var showsDone: Bool { state != .recorded }

    /// Retake once there is a take; Record before.
    var recordsAgain: Bool { state == .recorded }

    /// The record button is the screen's yellow fill, except on a recorded script that hasn't changed since its take.
    var recordIsPrimary: Bool { state != .recorded || changedSinceTake != nil }
}
