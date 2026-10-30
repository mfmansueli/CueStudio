//
//  UltraFlow.swift
//  Cue Studio
//

import Foundation

/// The passes an Ultra script goes through. Codex's lab found the polish didn't reliably catch wrong technical claims while it also applied the
/// voice, so `checked` gives the claims a call of their own (`UltraInstructions.checker`) before the polish; which one the app uses is decided
/// by the comparison with Apple Intelligence (`UltraQualityDeviceTests`).
nonisolated enum UltraFlow: String, CaseIterable, Hashable, Sendable {
    /// The draft, then its polish in the creator's voice (which also corrects claims).
    case polished
    /// The draft, then its claims checked on their own, then the polish in the creator's voice.
    case checked

    /// The calls a script takes, each counted against the lab's cap.
    var calls: Int { self == .checked ? 3 : 2 }
}
