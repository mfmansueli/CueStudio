//
//  InMemoryTakeRepository.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Keeps take metadata in memory; videos stay in the temporary folder. For previews and UI tests.
final class InMemoryTakeRepository: TakeRepository {
    private var takes: [Take]

    init(takes: [Take] = []) {
        self.takes = takes
    }

    func loadTakes() throws -> [Take] { takes }

    func saveTakes(_ takes: [Take]) throws { self.takes = takes }

    func storeVideo(from temporaryURL: URL) throws -> String { temporaryURL.lastPathComponent }

    func deleteVideo(named fileName: String) throws {}

    func videoURL(named fileName: String) -> URL { URL.temporaryDirectory.appending(path: fileName) }
}
#endif
