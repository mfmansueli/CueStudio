//
//  FontPackSource.swift
//  Cue Studio
//

import Foundation

/// Where a library file comes from. Today Google's own repository (`GoogleFontsPackSource`); the files could move to Apple-
/// hosted Background Assets or Cue's own server behind the same call, without touching the store or the pickers. The store
/// checks what comes back against the manifest either way.
nonisolated protocol FontPackSource: Sendable {
    /// The file's bytes; `progress` hears 0…1 as they come.
    func data(for file: FontPack.File, progress: @escaping @Sendable (Double) -> Void) async throws -> Data
}
