//
//  ScriptLibrarySnapshot.swift
//  Cue Studio
//

import Foundation

/// Everything the script library persists, written as one document.
nonisolated struct ScriptLibrarySnapshot: Codable, Equatable, Sendable {
    var scripts: [Script] = []
    var folders: [String] = []

    private enum CodingKeys: String, CodingKey {
        case scripts, folders
    }

    init(scripts: [Script] = [], folders: [String] = []) {
        self.scripts = scripts
        self.folders = folders
    }

    /// Script by script: one that can't be read stays out, never the whole library (`LossyList`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scripts = container.decodeLossy([Script].self, forKey: .scripts)
        folders = container.decodeLossy([String].self, forKey: .folders)
    }
}
