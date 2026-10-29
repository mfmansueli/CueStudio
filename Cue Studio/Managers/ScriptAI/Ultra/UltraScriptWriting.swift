//
//  UltraScriptWriting.swift
//  Cue Studio
//

import Foundation

/// What the script page asks of Ultra (`UltraScriptService`), so its view model is tested with a fake.
@MainActor
protocol UltraScriptWriting: AnyObject {
    /// Ultra is in this build and set up on this iPhone.
    var isAvailable: Bool { get }
    /// Available, and the creator allowed Google processing.
    var isReady: Bool { get }
    /// Scripts the creator may still write with Ultra; nil when nothing is counted.
    var scriptsLeft: Int? { get }
    /// The creator's plan as Ultra's allowance sees it; nil when nothing is counted.
    var membership: UltraAllowance.Membership? { get }
    /// Apple Intelligence wrote something for the creator (the invitation to try Ultra comes after the first time).
    func noteAIUse()
    /// Writes the developed draft and polishes it; only the polished script comes back. Throws `UltraError`, or `CancellationError`.
    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript
}
