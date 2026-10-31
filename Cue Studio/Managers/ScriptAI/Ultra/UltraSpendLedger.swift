//
//  UltraSpendLedger.swift
//  Cue Studio
//

import Foundation

/// What Ultra spent from this iPhone, request by request, in Google's token counts: every script and fit since the last fresh start, kept in the
/// app's standard defaults like the call cap (`UltraCallBudget`), so the lab says what a finished script costs on average and at most. A
/// measurement for the lab, not a bill: the project's bill, for every phone and the web lab together, is what `tools/ultra/spend.js` reads.
@MainActor
@Observable
final class UltraSpendLedger {
    static let key = "ultraLab.spend.v1"
    static let totalKey = "ultraLab.spend.total.v1"
    /// The requests kept one by one; the total keeps everything.
    static let keptEntries = 500

    private(set) var entries: [UltraSpendEntry]
    /// Everything spent since the last fresh start, the requests no longer kept one by one included.
    private(set) var total: UltraCost
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([UltraSpendEntry].self, from: $0) } ?? []
        total = defaults.data(forKey: Self.totalKey).flatMap { try? JSONDecoder().decode(UltraCost.self, from: $0) } ?? UltraCost()
    }

    func record(_ kind: UltraSpendEntry.Kind, cost: UltraCost, finished: Bool, at date: Date = .now) {
        guard cost.calls > 0 else { return }
        entries.append(UltraSpendEntry(kind: kind, date: date, cost: cost, finished: finished))
        if entries.count > Self.keptEntries { entries.removeFirst(entries.count - Self.keptEntries) }
        total += cost
        save()
    }

    /// The finished requests of one kind still kept; nil when there are none.
    func summary(of kind: UltraSpendEntry.Kind) -> UltraSpendSummary? {
        UltraSpendSummary(entries.filter { $0.kind == kind && $0.finished })
    }

    /// A new measurement (after a change to the prompts or the model): the calls already made stay counted by the cap.
    func startOver() {
        entries = []
        total = UltraCost()
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(entries), forKey: Self.key)
        defaults.set(try? JSONEncoder().encode(total), forKey: Self.totalKey)
    }
}
