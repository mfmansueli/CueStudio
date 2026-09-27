//
//  FakeScriptRepository.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeScriptRepository: ScriptRepository {
    var snapshot: ScriptLibrarySnapshot
    private(set) var saveCount = 0

    init(scripts: [Script] = [], folders: [String] = []) {
        snapshot = ScriptLibrarySnapshot(scripts: scripts, folders: folders)
    }

    func load() throws -> ScriptLibrarySnapshot { snapshot }

    func save(_ snapshot: ScriptLibrarySnapshot) throws {
        self.snapshot = snapshot
        saveCount += 1
    }
}
