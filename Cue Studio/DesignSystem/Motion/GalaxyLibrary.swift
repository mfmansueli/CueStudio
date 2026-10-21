//
//  GalaxyLibrary.swift
//  Cue Studio
//

import Foundation

/// The galaxies, loaded once from the bundle.
nonisolated enum GalaxyLibrary {
    static let art: GalaxyArt? = {
        guard let url = Bundle.main.url(forResource: "galaxies", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GalaxyArt.self, from: data)
    }()
}
