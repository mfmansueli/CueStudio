//
//  BackgroundTiles.swift
//  Cue Studio
//

import Foundation

/// Where the camera's movement is measured: a grid of tiles over the frame, leaving out the ones the people in it cover. Each
/// tile is measured on its own and the camera's movement is what most of them agree on (`CameraMotion`), so a creator talking
/// and gesturing, or someone walking through one tile, never reads as the camera moving. Pure.
nonisolated enum BackgroundTiles {
    /// Fewest tiles worth measuring on: with fewer left beside the people, every tile is measured (most still agree on the
    /// background).
    static let minimumCount = 4
    /// How much room is left around the people (as a share of their box).
    /// The grid: 4 × 6 tiles on a portrait frame, 6 × 4 on a landscape one.
    static let margin = 0.08

    /// The tiles of a frame `aspect` wide (width over height), from the top left, without the ones the people of `subject`
    /// cover.
    static func tiles(around subject: SubjectSample?, aspect: Double) -> [NormalizedBox] {
        let columns = aspect < 1 ? 4 : 6, rows = aspect < 1 ? 6 : 4
        let width = 1 / Double(columns), height = 1 / Double(rows)
        let all = (0..<rows).flatMap { row in
            (0..<columns).map { column in NormalizedBox(x: Double(column) * width, y: Double(row) * height, width: width, height: height) }
        }
        let people = (subject?.faces ?? []) + (subject?.bodies ?? [])
        guard !people.isEmpty else { return all }
        let covered = people.map { box in
            NormalizedBox(
                x: box.x - box.width * margin, y: box.y - box.height * margin,
                width: box.width * (1 + 2 * margin), height: box.height * (1 + 2 * margin)
            )
        }
        // A tile goes when a quarter of it or more is covered.
        let free = all.filter { tile in !covered.contains { $0.sharedArea(with: tile) >= tile.area * 0.25 } }
        return free.count >= minimumCount ? free : all
    }
}
