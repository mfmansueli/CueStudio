//
//  ScriptStrip.swift
//  Cue Studio
//

import Foundation

/// What the state strip on the script page says: the "Ready to record" switch (a draft or ready script) or RECORDED, and "Changed since
/// take 3" beside RECORDED once the words have moved on from the take; and whether the tools row offers "✦ Shape" (no cues yet).
/// No line of details beside the switch (owner, 31/10/2026: "Draft · Your script · No cues" cut "Ready to record" short, and said
/// what the switch, the words and the Cues pill already say). Leaving the page never changes the state: only the switch does (and
/// recording). Pure, so every state is tested.
nonisolated struct ScriptStrip: Equatable, Sendable {
    let state: ScriptState
    let cueCount: Int
    /// The number of the latest take, when the words changed after it ("CHANGED SINCE TAKE 3").
    let changedSinceTake: Int?
    /// The words were edited this visit (a recorded script has moved on from its take).
    let isEdited: Bool
    /// The tools row offers "✦ Shape": there are words, and no cues yet but a disclosure's. Shape is rules, so it is there without
    /// Apple Intelligence too.
    let canShape: Bool

    init(script: Script, takes: [Take], isEdited: Bool) {
        state = script.state(takeCount: takes.count)
        cueCount = CueParser.count(in: script.text)
        let latest = takes.max { $0.number < $1.number }
        // Editing a recorded script moves it on from its take even before the new version is saved.
        let changed = script.changedSince(latestTakeVersion: latest?.scriptVersion) || (isEdited && !takes.isEmpty)
        changedSinceTake = changed ? latest?.number : nil
        self.isEdited = isEdited
        canShape = ScriptCueShaper.cueCount(in: script.text) == 0 && !script.isEmpty
    }

    /// The one thing the strip says in words, in yellow beside RECORDED: "Changed since take 3", when the script has moved on from
    /// its take (what was recorded is no longer what is written). Nil otherwise: the switch says draft or ready by itself.
    var signal: String? {
        guard state == .recorded, let take = changedSinceTake else { return nil }
        return String(localized: "Changed since take \(take)")
    }

    /// A draft or ready script has the "Ready to record" switch; a recorded one says RECORDED (recording moved it there).
    var showsReadySwitch: Bool { state != .recorded }

    /// The switch is on.
    var isReady: Bool { state == .ready }

    /// Retake once there is a take; Record before.
    var recordsAgain: Bool { state == .recorded }
}
