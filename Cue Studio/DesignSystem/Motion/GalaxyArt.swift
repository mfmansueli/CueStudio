//
//  GalaxyArt.swift
//  Cue Studio
//

import Foundation

/// The galaxies of the 1.3 board, read from `galaxies.json` (`tools/bake_galaxies.py`): the creator's own ("YOU", a thousand stars and four
/// strokes of gas and light) and one per platform (two spiral arms and a few stars). The board draws its stars with a seeded generator and
/// writes them out; reading them back gives the same sky every time, and `GalaxyPainter` draws them.
nonisolated struct GalaxyArt: Decodable, Sendable {
    /// One spiral arm, a polyline in the galaxy's own plane, drawn blurred (the gas) or sharp (the light).
    struct Arm: Decodable, Sendable {
        var points: [[Double]]
        var width: Double
        var opacity: Double
        /// A colour (`#FFC46B`) on the hero's arms; the platform galaxies shade theirs with their own radial gradient.
        var stroke: String?
        var blurred: Bool
    }

    /// A star: where, how big, which colour (`#FFE08A`) and how bright.
    struct Star: Decodable, Sendable {
        var x: Double
        var y: Double
        var radius: Double
        var color: String
        var opacity: Double

        init(from decoder: Decoder) throws {
            var values = try decoder.unkeyedContainer()
            x = try values.decode(Double.self)
            y = try values.decode(Double.self)
            radius = try values.decode(Double.self)
            color = try values.decode(String.self)
            opacity = try values.decode(Double.self)
        }
    }

    /// A platform's galaxy: where it sits on the 390 × 844 board, how it is tilted and squashed, the radii of its glow, arms and core, its
    /// colour (rgb) and how long a turn takes (seconds).
    struct Social: Decodable, Sendable {
        var center: [Double]
        var rotation: Double
        var squash: Double
        var glowRadius: Double
        var coreRadius: Double
        var armRadius: Double
        var rgb: [Int]
        var spin: Double
        var arms: [Arm]
        var stars: [Star]
    }

    /// The creator's galaxy, drawn at 360 pt across.
    struct Hero: Decodable, Sendable {
        var arms: [Arm]
        var stars: [Star]
    }

    var socials: [String: Social]
    var hero: Hero
}

/// The galaxies, loaded once from the bundle.
nonisolated enum GalaxyLibrary {
    static let art: GalaxyArt? = {
        guard let url = Bundle.main.url(forResource: "galaxies", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GalaxyArt.self, from: data)
    }()
}
