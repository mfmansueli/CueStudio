//
//  FileExportLedgerStore.swift
//  Cue Studio
//

import Foundation
import os

/// The operations as a JSON file in Application Support (backed up with the device, not shown in Files).
final class FileExportLedgerStore: ExportLedgerStoring {
    private let url: URL
    private let logger = Logger(subsystem: "studio.cue", category: "ExportLedger")

    init(url: URL = FileExportLedgerStore.defaultURL) {
        self.url = url
    }

    nonisolated static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "ExportLedger.json")
    }

    func load() -> [ExportOperation] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([ExportOperation].self, from: data)
        } catch {
            logger.error("Could not read the export ledger: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ operations: [ExportOperation]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(operations).write(to: url, options: .atomic)
        } catch {
            logger.error("Could not save the export ledger: \(error.localizedDescription)")
        }
    }
}
