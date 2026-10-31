//
//  OfflineFontPackSource.swift
//  Cue Studio
//

import Foundation

/// A source that never reaches the network: the editor without the app's stores (tests, previews) and the UI tests' in-memory
/// runs. Every download fails, so the words stay in the system's faces of their scripts.
nonisolated struct OfflineFontPackSource: FontPackSource {
    struct Offline: Error {}

    func data(for file: FontPack.File, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        throw Offline()
    }
}
