//
//  FakeExportLedgerStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The ledger's disk, kept in memory: a second `ExportLedgerService` on the same store is the app after a restart.
@MainActor
final class FakeExportLedgerStore: ExportLedgerStoring {
    var operations: [ExportOperation]
    private(set) var saves = 0

    init(operations: [ExportOperation] = []) {
        self.operations = operations
    }

    func load() -> [ExportOperation] { operations }

    func save(_ operations: [ExportOperation]) {
        self.operations = operations
        saves += 1
    }
}
