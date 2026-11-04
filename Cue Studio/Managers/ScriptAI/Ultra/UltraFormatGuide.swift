//
//  UltraFormatGuide.swift
//  Cue Studio
//

import Foundation

/// The format line Ultra's writer and editor get (`UltraPayload`): what the creator's chosen format needs, not only its name
/// (`ScriptFormatDefinitions`). In the blind study of 04/11/2026 (`tools/ultra/study`, 44 requests, three judges) the definition lifted every
/// setting by 4 to 5 points of 100 over the bare label ("Format chosen by the creator: storytimes."), Opus at low effort from 86.0 to 91.2,
/// above Opus high with the label (88.9).
nonisolated enum UltraFormatGuide {
    /// The line for `request`'s format: the chosen one's definition; on Auto, the genre of the card's idea, or how to read it from the request.
    static func line(for request: ScriptRequest) -> String {
        if request.formatChoice == .talkingHead { return ScriptFormatDefinitions.talkingHeadLine }
        if let type = request.type { return ScriptFormatDefinitions.chosenLine(for: type) }
        if let kind = request.ideaKind, let line = ScriptFormatDefinitions.ideaLine(for: kind) { return line }
        return "Format: not chosen. Read the genre from the request (tutorial, story, opinion, list, review, comparison, explanation…); the "
            + "creator's usual formats only help when the request is vague."
    }
}
