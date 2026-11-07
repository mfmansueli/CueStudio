//
//  PauseHearing.swift
//  Cue Studio
//

import Foundation

/// How sure Clean Up could be of a recording's pauses, from its loudness (`SilenceDetector.pauses`). In a quiet room a pause is
/// what falls under a fixed silence level, as always. A fan, traffic or music can sit above that level, and a soft voice can sit
/// close to it: then the level follows the background (or the voice), and what it finds that way is listed for a listen but never
/// marked to go (D16, owner 07/11/2026: in doubt, let a pause pass rather than suggest removing speech).
nonisolated enum PauseHearing: String, Codable, Hashable, Sendable, CaseIterable {
    /// A quiet room and a voice well above the silence level: pauses as always, marked to go.
    case clear
    /// The background is louder than the silence level and the voice stands clear of it: the level rose with it. The pauses it
    /// found are listed unmarked.
    case overBackgroundSound
    /// A quiet room but a soft voice, close to the silence level (where that level would take quiet words for pauses): the level
    /// went down, under the voice. The pauses it found are listed unmarked.
    case softVoice
    /// Too much background sound to tell pauses from quiet speech: nothing found by a moved level is listed, only silences under the
    /// fixed level (usually none). Filler words and retakes, heard in the transcript, still are.
    case tooMuchBackgroundSound

    /// The analysis couldn't tell, so "no pauses" doesn't mean the take flows.
    var isInconclusive: Bool { self == .tooMuchBackgroundSound }

    /// How careful Clean Up had to be, for the summary of several recordings (the most careful one speaks for them).
    var caution: Int {
        switch self {
        case .clear: 0
        case .softVoice: 1
        case .overBackgroundSound: 2
        case .tooMuchBackgroundSound: 3
        }
    }

    /// What Pauses can say about it: "Too much background sound"; nil when the pauses were heard clearly.
    var title: String? {
        switch self {
        case .clear: nil
        case .overBackgroundSound: String(localized: "Heard over background sound")
        case .softVoice: String(localized: "Soft voice")
        case .tooMuchBackgroundSound: String(localized: "Too much background sound")
        }
    }

    /// The line under the title: what the creator can do.
    var detail: String? {
        switch self {
        case .clear: nil
        case .overBackgroundSound, .softVoice: String(localized: "Listen first · none is marked")
        case .tooMuchBackgroundSound: String(localized: "Pauses can’t be found reliably here. Try Edit by text.")
        }
    }
}
