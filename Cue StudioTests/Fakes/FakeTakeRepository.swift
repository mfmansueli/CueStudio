//
//  FakeTakeRepository.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeTakeRepository: TakeRepository {
    var takes: [Take]
    private(set) var deletedFiles: [String] = []
    private(set) var storedFiles: [String] = []
    /// Like a library that can't take the file in (its folder can't be made): the recording stays where it was.
    var failsToStore = false

    init(takes: [Take] = []) {
        self.takes = takes
    }

    func loadTakes() throws -> [Take] { takes }

    func saveTakes(_ takes: [Take]) throws { self.takes = takes }

    func storeVideo(from temporaryURL: URL) throws -> String {
        if failsToStore { throw CocoaError(.fileWriteUnknown) }
        let name = temporaryURL.lastPathComponent
        storedFiles.append(name)
        return name
    }

    func deleteVideo(named fileName: String) throws {
        deletedFiles.append(fileName)
    }

    func videoURL(named fileName: String) -> URL {
        URL.temporaryDirectory.appending(path: fileName)
    }
}
