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

    /// The video stays in the temporary folder, but a camera recording leaves its `take-` name: kept, the next real launch
    /// would take it for one a crash left (`TakeRecovery`) and put a UI test's take in the creator's library.
    func storeVideo(from temporaryURL: URL) throws -> String {
        let name = temporaryURL.lastPathComponent
        guard name.hasPrefix(TakeRecovery.prefix) else { return name }
        let kept = "memory-" + name
        guard (try? FileManager.default.moveItem(at: temporaryURL, to: videoURL(named: kept))) != nil else { return name }
        return kept
    }

    func deleteVideo(named fileName: String) throws {}

    func videoURL(named fileName: String) -> URL { URL.temporaryDirectory.appending(path: fileName) }
}
#endif
