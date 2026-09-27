//
//  ScriptLibrarySnapshot.swift
//  Cue Studio
//

import Foundation

/// Everything the script library persists, written as one document.
nonisolated struct ScriptLibrarySnapshot: Codable, Equatable, Sendable {
    var scripts: [Script] = []
    var folders: [String] = []
}
