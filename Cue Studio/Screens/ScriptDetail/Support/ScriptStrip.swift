//
//  ScriptStrip.swift
//  Cue Studio
//

import Foundation

/// What the state strip on the script page says: the "Ready to record" switch (a draft or ready script) or RECORDED, then the format
/// and how many cues ("Draft · List · 4 cues"), and "✦ Shape" when there are none. Leaving the page never changes the state: only the
/// switch does (and recording). Pure, so every state is tested.
nonisolated struct ScriptStrip: Equatable, Sendable {
    let state: ScriptState
    /// The script's format; nil says "Your script".
    let formatLabel: String?
    let cueCount: Int
    /// The number of the latest take, when the words changed after it ("CHANGED SINCE TAKE 3").
    let changedSinceTake: Int?
    /// The words were edited this visit (a recorded script has moved on from its take).
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

    /// The line beside the switch: "Draft · List · 4 cues", "List · 4 cues" once ready, "Changed since take 3" after a take.
    var info: [String] {
        if state == .recorded, let take = changedSinceTake {
            return [String(localized: "Changed since take \(take)")]
        }
        let details = [formatLabel ?? String(localized: "Your script"), ScriptRowLine.cues(cueCount)]
        return state == .draft ? [String(localized: "Draft")] + details : details
    }

    /// The line is a signal (yellow) when the script has moved on from its take.
    var isSignal: Bool { state == .recorded && changedSinceTake != nil }

    /// A draft or ready script has the "Ready to record" switch; a recorded one says RECORDED (recording moved it there).
    var showsReadySwitch: Bool { state != .recorded }

    /// The switch is on.
    var isReady: Bool { state == .ready }

    /// Retake once there is a take; Record before.
    var recordsAgain: Bool { state == .recorded }

    /// The record button is the screen's yellow fill, except on a recorded script that hasn't changed since its take.
    var recordIsPrimary: Bool { state != .recorded || changedSinceTake != nil }
}
