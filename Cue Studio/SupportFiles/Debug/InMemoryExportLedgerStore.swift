//
//  InMemoryExportLedgerStore.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// UI tests start with no export operations, whatever an earlier run left on disk.
final class InMemoryExportLedgerStore: ExportLedgerStoring {
    private var operations: [ExportOperation] = []

    func load() -> [ExportOperation] { operations }

    func save(_ operations: [ExportOperation]) { self.operations = operations }
}
#endif
