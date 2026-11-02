//
//  CreatorVoice+Ending.swift
//  Cue Studio
//

import Foundation

/// How a creator's scripts end, in the order the owner set on 02/11/2026 (B1, B11): what the request asks wins, then a "never" (Avoid ›
/// Calls to action), then the ending they usually use ("How you usually end", a habit), and only then the platform's convention. A creator
/// with any of these never gets the platform's "end with one easy action" on top of theirs.
nonisolated extension CreatorVoice {
    /// They never ask the viewer for anything (Avoid › Calls to action): a rule.
    var forbidsCallsToAction: Bool {
        avoid.contains { VoiceTextValidator.key($0) == VoiceTextValidator.key(VoiceAvoidRule.callsToActionID) }
    }

    /// Their scripts end without asking for anything: the rule, or "No call to action" as the only ending they picked.
    var endsWithoutAsking: Bool {
        forbidsCallsToAction || (!endings.isEmpty && endingActions.isEmpty)
    }

    /// Their usual ending as the model reads it ("asking viewers to save the video", `saying “See you Sunday”`), without "No call to action",
    /// which asks nothing, and without the endings of Cue's that ask for something when they never ask (the rule beats the habit): a sign-off
    /// they typed stays.
    var endingActions: [String] {
        endings.compactMap { stored in
            switch VoiceChoiceCatalog.ending(stored) {
            case .known(let id, let guidance): id == "No call to action" || forbidsCallsToAction ? nil : guidance
            case .typed(let text): "saying “\(text)”"
            }
        }
    }

    /// Something of theirs decides the ending, so the platform's convention doesn't.
    var decidesTheEnding: Bool {
        forbidsCallsToAction || !endings.isEmpty
    }
}
