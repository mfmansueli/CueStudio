//
//  UltraRun.swift
//  Cue Studio
//

import Foundation

/// One finished Ultra script and how it was made: the polished script, the draft it came from, the claim check's version and corrections when
/// there was one (`UltraFlow.checked`) and the editor's list of changes (the lab shows them side by side), each call's time and tokens, and
/// what all its calls cost.
/// Kept in memory only; the script page saves `script` alone.
nonisolated struct UltraRun: Hashable, Sendable {
    var script: GeneratedScript
    var draft: String
    var changes: [String]
    var draftSeconds: Double
    var reviewSeconds: Double
    var draftReply: UltraModelReply
    var reviewReply: UltraModelReply
    var flow = UltraFlow.standard
    /// The draft after the claim check (nil without one).
    var checked: String?
    var corrections: [String] = []
    var checkSeconds: Double?
    var checkReply: UltraModelReply?
    /// Every call of the run, the fit that followed by itself included.
    var cost = UltraCost()
}
