//
//  ScriptRepository.swift
//  Cue Studio
//

import Foundation

/// Where scripts are stored. Swappable so tests and previews never touch the disk.
protocol ScriptRepository {
    func load() throws -> ScriptLibrarySnapshot
    func save(_ snapshot: ScriptLibrarySnapshot) throws
}
