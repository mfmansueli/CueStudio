//
//  FontPackManifest.swift
//  Cue Studio
//

import Foundation

/// The script libraries: every family Cue can download, by script (`SupportFiles/FontPacks.json`, written by
/// `tools/fonts/make_manifest.py` from one pinned commit of github.com/google/fonts). Only this list ships in the app; the fonts
/// come when a video needs them.
nonisolated struct FontPackManifest: Codable, Hashable, Sendable {
    /// Where the files come from ("github.com/google/fonts@<commit>").
    var source: String
    var packs: [FontPack]

    /// The list in the app.
    static let bundled: FontPackManifest = {
        guard let url = Bundle.main.url(forResource: "FontPacks", withExtension: "json"), let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(FontPackManifest.self, from: data) else {
            return FontPackManifest(source: "", packs: [])
        }
        return manifest
    }()

    func pack(_ id: String) -> FontPack? {
        packs.first { $0.id == id }
    }

    /// A script's families, in the order the library shows them.
    func packs(for script: WritingScript) -> [FontPack] {
        packs.filter { $0.script == script }
    }
}
