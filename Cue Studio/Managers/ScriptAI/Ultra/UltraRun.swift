//
//  UltraRun.swift
//  Cue Studio
//

import Foundation

/// One finished Ultra script and how it was made: the polished script, the draft it came from and the editor's list of changes (the lab shows
/// them side by side), and each call's time and tokens. Kept in memory only; the script page saves `script` alone.
nonisolated struct UltraRun: Hashable, Sendable {
    var script: GeneratedScript
    var draft: String
    var changes: [String]
    var draftSeconds: Double
    var reviewSeconds: Double
    var draftReply: UltraModelReply
    var reviewReply: UltraModelReply
}
