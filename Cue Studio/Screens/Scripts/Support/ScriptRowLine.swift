//
//  ScriptRowLine.swift
//  Cue Studio
//

import Foundation

/// The mono line under a script's title (v29), in capitals: "TIKTOK" for a script that is ready (the owner took its length, cues and
/// topic off the list, 30/10/2026), "SHORTS · 2H AGO" for a draft, "TIKTOK · 3 TAKES · READY" once there are takes (the video's own
/// stage, the same `TakeStage` the Takes tab shows).
nonisolated struct ScriptRowLine: Equatable, Sendable {
    let values: [String]

    init(script: Script, state: ScriptState, takes: [Take], hasDraft: (UUID) -> Bool) {
        var values = [script.platform.label]
        switch state {
        case .ready:
            break
        case .draft:
            values.append(script.isEmpty ? String(localized: "Blank") : Self.ago(script.updatedAt))
        case .recorded:
            values.append(takes.count == 1 ? String(localized: "1 take") : String(localized: "\(takes.count) takes"))
            values.append(TakeStage(takes: takes, hasDraft: hasDraft).pipelineLabel)
        }
        self.values = values
    }

    /// "2h ago", "yesterday", in the interface's language.
    static func ago(_ date: Date) -> String {
        var style = Date.RelativeFormatStyle(presentation: .named, unitsStyle: .narrow)
        style.locale = Locale.interface
        return date.formatted(style)
    }
}
