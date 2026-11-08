//
//  QuickEditDraftStore.swift
//  Cue Studio
//

import Foundation
import os

/// Quick edit drafts as small JSON files in Application Support, named by take. A draft that can't be read whole (damaged, or a
/// newer Cue's) is copied to `Kept` before anything can be written over it, and the editor says so: the take's saved edit is still
/// there, and the copy stays until the take is deleted (the newest three per take).
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
        reading(for: takeID).draft
    }

    func reading(for takeID: UUID) -> QuickEditDraftReading {
        let url = fileURL(for: takeID), kept = keptDirectory
        return writes.sync { Self.read(url, takeID: takeID, keptIn: kept) }
    }

    func hasDraft(for takeID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: takeID).path(percentEncoded: false))
    }

    func save(_ draft: QuickEditDraft) throws {
        let directory = directory, url = fileURL(for: draft.takeID)
        try writes.sync { try Self.write(draft, to: url, in: directory) }
    }

    func saveSoon(_ draft: QuickEditDraft, then: @escaping @MainActor @Sendable (QuickEditDraftSaveFailure?) -> Void) {
        let directory = directory, url = fileURL(for: draft.takeID)
        writes.async {
            var failure: QuickEditDraftSaveFailure?
            do {
                try Self.write(draft, to: url, in: directory)
            } catch {
                failure = QuickEditDraftSaveFailure(error)
            }
            Task { @MainActor in then(failure) }
        }
    }

    func discard(takeID: UUID) {
        let url = fileURL(for: takeID)
        writes.sync {
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    func forget(takeID: UUID) {
        let url = fileURL(for: takeID), kept = keptDirectory
        writes.sync {
            try? FileManager.default.removeItem(at: url)
            for copy in Self.keptCopies(of: takeID, in: kept) { try? FileManager.default.removeItem(at: copy) }
        }
    }

    func discardAll() {
        let directory = directory
        writes.sync { _ = try? FileManager.default.removeItem(at: directory) }
    }

    private func fileURL(for takeID: UUID) -> URL {
        directory.appending(path: "\(takeID.uuidString).json")
    }

    private var keptDirectory: URL { directory.appending(path: "Kept", directoryHint: .isDirectory) }

    /// The copies kept per take: enough to go back past a couple of bad reads, few enough not to pile up.
    nonisolated static let keptPerTake = 3

    private nonisolated static func read(_ url: URL, takeID: UUID, keptIn kept: URL) -> QuickEditDraftReading {
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .none }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.error("Could not read Quick edit draft file: \(error.localizedDescription)")
            return .unreadable
        }
        do {
            let report = DecodingReport()
            let draft = try JSONDecoder().reporting(to: report).decode(QuickEditDraft.self, from: data)
            let notes = report.notes
            guard !notes.isEmpty else { return .draft(draft, partial: false) }
            logger.error("Quick edit draft read with \(notes.count) parts left out or read as a stand-in: \(notes.joined(separator: "; "), privacy: .public)")
            keep(data, of: takeID, in: kept)
            return .draft(draft, partial: true)
        } catch {
            logger.error("Could not read Quick edit draft: \(error.localizedDescription)")
            keep(data, of: takeID, in: kept)
            return .unreadable
        }
    }

    /// A draft that didn't read whole, as it was on disk: once per content, the newest `keptPerTake` per take.
    private nonisolated static func keep(_ data: Data, of takeID: UUID, in kept: URL) {
        let copies = keptCopies(of: takeID, in: kept)
        if copies.contains(where: { (try? Data(contentsOf: $0)) == data }) { return }
        do {
            try FileManager.default.createDirectory(at: kept, withIntermediateDirectories: true)
            let stamp = Int(Date.now.timeIntervalSince1970 * 1000)
            try data.write(to: kept.appending(path: "\(takeID.uuidString)-\(stamp).json"), options: .atomic)
        } catch {
            logger.error("Could not keep a copy of a Quick edit draft: \(error.localizedDescription)")
            return
        }
        for old in keptCopies(of: takeID, in: kept).dropFirst(keptPerTake) { try? FileManager.default.removeItem(at: old) }
    }

    /// Newest first.
    private nonisolated static func keptCopies(of takeID: UUID, in kept: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: kept.path(percentEncoded: false))) ?? []
        return names.filter { $0.hasPrefix(takeID.uuidString + "-") && $0.hasSuffix(".json") }
            .sorted { $0 > $1 }
            .map { kept.appending(path: $0) }
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
