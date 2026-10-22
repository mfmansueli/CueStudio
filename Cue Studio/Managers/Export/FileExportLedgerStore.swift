//
//  FileExportLedgerStore.swift
//  Cue Studio
//

import Foundation
import os

/// The operations as a JSON file in Application Support (backed up with the device, not shown in Files). A damaged file is
/// kept aside before a new one is written (`ExportLedger-kept-<date>.json`), like the libraries do; one that is there but
/// can't be read now is never written over.
final class FileExportLedgerStore: ExportLedgerStoring {
    private let url: URL
    private let logger = Logger(subsystem: "studio.cue", category: "ExportLedger")
    /// The file was there at `load` but couldn't be read (the iPhone not unlocked since it started, a read error): the next
    /// save reads it again and keeps its operations, or sets it aside, instead of writing over it.
    private var unread = false

    init(url: URL = FileExportLedgerStore.defaultURL) {
        self.url = url
    }

    nonisolated static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "ExportLedger.json")
    }

    func load() -> [ExportOperation] {
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.error("Could not read the export ledger: \(error.localizedDescription)")
            unread = true
            return []
        }
        // Entry by entry: one that can't be read stays out, never the whole record of what was exported. The file as it was
        // is kept aside first, since the next save writes the ledger without it.
        guard let list = try? JSONDecoder().decode(LossyList<ExportOperation>.self, from: data) else {
            logger.error("The export ledger is damaged: kept aside, a new one starts")
            keepCopy(of: data)
            return []
        }
        if list.dropped > 0 { keepCopy(of: data) }
        return list.elements
    }

    func save(_ operations: [ExportOperation]) {
        var operations = operations
        if unread {
            unread = false
            let known = Set(operations.map(\.id))
            let earlier = load()
            if unread {
                // Still unreadable: set aside as it is, never written over. If even that fails, nothing is saved this time.
                guard setAside() else { return }
                unread = false
            }
            operations = earlier.filter { !known.contains($0.id) } + operations
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(operations).write(to: url, options: .atomic)
        } catch {
            logger.error("Could not save the export ledger: \(error.localizedDescription)")
        }
    }

    // MARK: - Kept copies

    /// `ExportLedger-kept-<date>.json`, next to the ledger.
    private var keptCopyURL: URL {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        return url.deletingLastPathComponent().appending(path: "\(url.deletingPathExtension().lastPathComponent)-kept-\(stamp).json")
    }

    /// The ledger as it was, next to it, once per damaged file.
    private func keepCopy(of data: Data) {
        try? data.write(to: keptCopyURL, options: .atomic)
    }

    /// The ledger moved aside as it is (a file that can't be read can still be moved). False when it stays where it was.
    private func setAside() -> Bool {
        do {
            try FileManager.default.moveItem(at: url, to: keptCopyURL)
            return true
        } catch {
            logger.error("Could not set the unreadable export ledger aside: \(error.localizedDescription)")
            return false
        }
    }
}
