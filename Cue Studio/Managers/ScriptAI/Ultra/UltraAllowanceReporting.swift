//
//  UltraAllowanceReporting.swift
//  Cue Studio
//

import Foundation

/// A client that can ask Cue's server what the creator has left (`CueServerUltraClient`, and the lab's when it goes through the server).
@MainActor
protocol UltraAllowanceReporting: AnyObject {
    func allowance(for caller: UltraCaller) async throws -> UltraServerAllowance
}
