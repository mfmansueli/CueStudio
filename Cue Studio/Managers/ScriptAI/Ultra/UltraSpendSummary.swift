//
//  UltraSpendSummary.swift
//  Cue Studio
//

import Foundation

/// What one kind of finished Ultra request costs on this iPhone (`UltraSpendLedger.summary(of:)`), in dollars.
nonisolated struct UltraSpendSummary: Hashable, Sendable {
    var count: Int
    var mean: Double
    var most: Double
    /// Calls per request, on average (a script's fit that followed by itself raises it).
    var meanCalls: Double

    /// Nil for no entries.
    init?(_ entries: [UltraSpendEntry]) {
        guard !entries.isEmpty else { return nil }
        let dollars = entries.map { $0.cost.dollars() }
        count = entries.count
        mean = dollars.reduce(0, +) / Double(entries.count)
        most = dollars.max() ?? 0
        meanCalls = Double(entries.map(\.cost.calls).reduce(0, +)) / Double(entries.count)
    }
}
