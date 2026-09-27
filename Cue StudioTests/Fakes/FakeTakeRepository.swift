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

    init(takes: [Take] = []) {
        self.takes = takes
    }

    func loadTakes() throws -> [Take] { takes }

    func saveTakes(_ takes: [Take]) throws { self.takes = takes }

    func storeVideo(from temporaryURL: URL) throws -> String {
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
