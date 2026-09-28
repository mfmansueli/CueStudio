//
//  QuickEditDraftStore.swift
//  Cue Studio
//

import Foundation
import os

/// Quick edit drafts as small JSON files in Application Support, named by take. A draft that
/// can't be read is treated as none: the take's saved edit is still there.
final class QuickEditDraftStore: QuickEditDraftStoring {
    private let directory: URL
    private let logger = Logger(subsystem: "studio.cue", category: "QuickEditDrafts")

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "QuickEditDrafts", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func draft(for takeID: UUID) -> QuickEditDraft? {
        let url = fileURL(for: takeID)
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        do {
            return try JSONDecoder().decode(QuickEditDraft.self, from: Data(contentsOf: url))
        } catch {
            logger.error("Could not read Quick edit draft: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ draft: QuickEditDraft) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(draft).write(to: fileURL(for: draft.takeID), options: .atomic)
        } catch {
            logger.error("Could not save Quick edit draft: \(error.localizedDescription)")
        }
    }

    func discard(takeID: UUID) {
        let url = fileURL(for: takeID)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func fileURL(for takeID: UUID) -> URL {
        directory.appending(path: "\(takeID.uuidString).json")
    }
}
