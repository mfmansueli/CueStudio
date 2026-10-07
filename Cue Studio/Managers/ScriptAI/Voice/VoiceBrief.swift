//
//  VoiceBrief.swift
//  Cue Studio
//

import Foundation

/// A creator's voice as the AI is told it, and what "What Cue sends" shows: the same text, measured the same way. It fits in `budget`
/// characters; what had to go to fit is listed in `trimmed`.
nonisolated struct VoiceBrief: Hashable, Sendable {
    /// The most the AI is sent of the voice, in characters of English (`PromptCost`): about 640 tokens of the model's 4096, with the instructions, the idea
    /// and the script it writes to come on top. It was 1200 (the prototype's number, never measured); on an iPhone 15 Pro a request with a 1200
    /// character voice is 794 tokens and the model starts answering in 1.7 s, with no voice 427 and 1.4 s, so a voice twice as long still leaves three
    /// quarters of the window for the script. Only the device measurement of the budget (`PromptBudgetDeviceTests`) changes it.
    nonisolated(unsafe) static var budget = 2100

    /// What can be left out to make it fit, in the order cutting goes: the examples first, then where and how long they post, and last the tags: those
    /// are what the creator typed under "+ Something else" where the app had no list (a kind of tone, a format, a reason to watch), the one thing in the
    /// brief that only they said.
    enum Trimmed: String, CaseIterable, Hashable, Sendable {
        case examples, reach, tags
    }

    /// What is sent.
    let text: String
    /// What would be sent with no limit.
    let fullText: String
    /// What was cut, in cutting order.
    let trimmed: [Trimmed]
    /// The rules the request says again at its very end, where the model attends best: who is talking, what to avoid, how not to open.
    let closingRules: [String]

    /// What is sent costs this much of the budget (`PromptCost`): its characters, more for scripts that take more tokens.
    var cost: Int { PromptCost.units(of: text) }
    var fullCost: Int { PromptCost.units(of: fullText) }
    var length: Int { text.count }
    var fullLength: Int { fullText.count }
    var isEmpty: Bool { text.isEmpty }
    /// The brief with no limit doesn't fit: Cue trims it.
    var isLong: Bool { fullCost > Self.budget }
    var lines: [String] { text.isEmpty ? [] : text.components(separatedBy: "\n") }

    static let empty = VoiceBrief(text: "", fullText: "", trimmed: [], closingRules: [])
}
