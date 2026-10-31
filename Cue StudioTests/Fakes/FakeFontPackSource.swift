//
//  FakeFontPackSource.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Serves library files without the network: each file's bytes from `files` (by file name), or a failure; counts the asks.
nonisolated final class FakeFontPackSource: FontPackSource, @unchecked Sendable {
    struct Missing: Error {}

    private let lock = NSLock()
    private var served: [String: Data]
    private var asked: [String] = []

    init(files: [String: Data] = [:]) {
        served = files
    }

    var asks: [String] {
        lock.withLock { asked }
    }

    func data(for file: FontPack.File, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        let data = lock.withLock { () -> Data? in
            asked.append(file.file)
            return served[file.file]
        }
        progress(0.5)
        guard let data else { throw Missing() }
        progress(1)
        return data
    }
}
