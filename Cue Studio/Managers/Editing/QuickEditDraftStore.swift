//
//  QuickEditDraftStore.swift
//  Cue Studio
//

import Foundation
import os

/// Quick edit drafts as small JSON files in Application Support, named by take. A draft that
/// can't be read is treated as none: the take's saved edit is still there.
///
/// Every write, read and discard goes through one serial queue: the autosave (`saveSoon`) is encoded and written there, off
/// the main thread, and anything asked for after it (a read, a discard, the draft kept on leaving) waits for it, so an older
/// draft never lands over a newer one or comes back after a discard. Undo steps are written thinned (`QuickEditDraft.thinned`).
final class QuickEditDraftStore: QuickEditDraftStoring {
    private let directory: URL
    private let writes = DispatchQueue(label: "studio.cue.drafts", qos: .utility)
    private nonisolated static let logger = Logger(subsystem: "studio.cue", category: "QuickEditDrafts")

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "QuickEditDrafts", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func draft(for takeID: UUID) -> QuickEditDraft? {
        let url = fileURL(for: takeID)
        return writes.sync { Self.read(url) }
    }

    func hasDraft(for takeID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: takeID).path(percentEncoded: false))
    }

    func save(_ draft: QuickEditDraft) throws {
        let directory = directory, url = fileURL(for: draft.takeID)
        try writes.sync { try Self.write(draft, to: url, in: directory) }
    }

    func saveSoon(_ draft: QuickEditDraft) {
        let directory = directory, url = fileURL(for: draft.takeID)
        writes.async { try? Self.write(draft, to: url, in: directory) }
    }

    func discard(takeID: UUID) {
        let url = fileURL(for: takeID)
        writes.sync {
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    func discardAll() {
        let directory = directory
        writes.sync { _ = try? FileManager.default.removeItem(at: directory) }
    }

    private func fileURL(for takeID: UUID) -> URL {
        directory.appending(path: "\(takeID.uuidString).json")
    }

    private nonisolated static func read(_ url: URL) -> QuickEditDraft? {
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        do {
            let report = DecodingReport()
            let draft = try JSONDecoder().reporting(to: report).decode(QuickEditDraft.self, from: Data(contentsOf: url))
            let notes = report.notes
            if !notes.isEmpty {
                logger.error("Quick edit draft read with \(notes.count) parts left out or read as a stand-in: \(notes.joined(separator: "; "), privacy: .public)")
            }
            return draft
        } catch {
            logger.error("Could not read Quick edit draft: \(error.localizedDescription)")
            return nil
        }
    }

    private nonisolated static func write(_ draft: QuickEditDraft, to url: URL, in directory: URL) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(draft.thinned()).write(to: url, options: .atomic)
        } catch {
            logger.error("Could not save Quick edit draft: \(error.localizedDescription)")
            throw error
        }
    }
}
