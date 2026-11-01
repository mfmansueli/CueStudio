//
//  TakeRecoveryNote.swift
//  Cue Studio
//

import Foundation

/// What a take's recording was read from, written next to it when the library couldn't take it in (`TakeLibraryService.addTake`):
/// `TakeRecovery` files it under its script again at the next launch, not as a freestyle recording.
nonisolated struct TakeRecoveryNote: Codable, Equatable, Sendable {
    var scriptID: UUID
    var scriptVersion: Int

    /// Its name: the recording's, and this.
    static let suffix = ".note.json"

    static func url(for recording: URL) -> URL {
        recording.deletingLastPathComponent().appending(path: recording.lastPathComponent + suffix)
    }

    /// Written for `recording`; a note that can't be written leaves the take to come back as freestyle, as before.
    func write(for recording: URL) {
        try? JSONEncoder().encode(self).write(to: Self.url(for: recording), options: .atomic)
    }

    static func read(for recording: URL) -> TakeRecoveryNote? {
        guard let data = try? Data(contentsOf: url(for: recording)) else { return nil }
        return try? JSONDecoder().decode(TakeRecoveryNote.self, from: data)
    }

    static func remove(for recording: URL) {
        try? FileManager.default.removeItem(at: url(for: recording))
    }
}
