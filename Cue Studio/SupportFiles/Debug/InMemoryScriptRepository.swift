//
//  InMemoryScriptRepository.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Keeps the library in memory, for previews and UI tests.
final class InMemoryScriptRepository: ScriptRepository {
    private var snapshot: ScriptLibrarySnapshot

    init(scripts: [Script] = [], folders: [String] = []) {
        snapshot = ScriptLibrarySnapshot(scripts: scripts, folders: folders)
    }

    func load() throws -> ScriptLibrarySnapshot { snapshot }

    func save(_ snapshot: ScriptLibrarySnapshot) throws { self.snapshot = snapshot }
}
#endif
