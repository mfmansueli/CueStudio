//
//  ScriptRowLine.swift
//  Cue Studio
//

import Foundation

/// The mono line under a script's title (v29), in capitals: "TIKTOK · 0:47 · 4 CUES" for a script that is ready,
/// "SHORTS · 2H AGO" for a draft, "TIKTOK · 3 TAKES · READY" once there are takes (the video's own stage, the same
/// `TakeStage` the Takes tab shows).
nonisolated struct ScriptRowLine: Equatable, Sendable {
    let values: [String]

    init(script: Script, state: ScriptState, readSeconds: TimeInterval, takes: [Take], hasDraft: (UUID) -> Bool) {
        var values = [script.platform.label]
        switch state {
        case .ready:
            values.append(DurationText.clock(readSeconds))
            values.append(Self.cues(CueParser.count(in: script.text)))
        case .draft:
            values.append(script.isEmpty ? String(localized: "Blank") : Self.ago(script.updatedAt))
        case .recorded:
            values.append(takes.count == 1 ? String(localized: "1 take") : String(localized: "\(takes.count) takes"))
            values.append(TakeStage(takes: takes, hasDraft: hasDraft).pipelineLabel)
        }
        self.values = values
    }

    /// "4 cues", "1 cue", "No cues".
    static func cues(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No cues")
        case 1: String(localized: "1 cue")
        default: String(localized: "\(count) cues")
        }
    }

    /// "2h ago", "yesterday", in the interface's language.
    static func ago(_ date: Date) -> String {
        var style = Date.RelativeFormatStyle(presentation: .named, unitsStyle: .narrow)
        style.locale = Locale.interface
        return date.formatted(style)
    }
}
