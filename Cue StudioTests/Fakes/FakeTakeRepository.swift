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
    /// The videos put back where they came from (`returnVideo`), by stored name.
    private(set) var returnedFiles: [String: URL] = [:]
    /// Like a library that can't take the file in (its folder can't be made): the recording stays where it was.
    var failsToStore = false
    /// Like a full iPhone: the library reads, but writing it fails.
    var failsToSave = false

    init(takes: [Take] = []) {
        self.takes = takes
    }

    func loadTakes() throws -> [Take] { takes }

    func saveTakes(_ takes: [Take]) throws {
        if failsToSave { throw CocoaError(.fileWriteOutOfSpace) }
        self.takes = takes
    }

    func storeVideo(from temporaryURL: URL) throws -> String {
        if failsToStore { throw CocoaError(.fileWriteUnknown) }
        let name = temporaryURL.lastPathComponent
        storedFiles.append(name)
        return name
    }

    func returnVideo(named fileName: String, to temporaryURL: URL) throws {
        returnedFiles[fileName] = temporaryURL
    }

    func deleteVideo(named fileName: String) throws {
        deletedFiles.append(fileName)
    }

    func videoURL(named fileName: String) -> URL {
        URL.temporaryDirectory.appending(path: fileName)
    }
}
