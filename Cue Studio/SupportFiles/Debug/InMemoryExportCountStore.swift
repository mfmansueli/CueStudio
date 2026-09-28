//
//  InMemoryExportCountStore.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// UI tests start with every free export, whatever an earlier run used.
final class InMemoryExportCountStore: ExportCountStoring {
    private var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    func load() -> Int { count }

    func save(_ count: Int) { self.count = count }
}
#endif
