//
//  UniverseYearRequest.swift
//  Cue Studio
//

import Foundation

/// A year a sheet or a story is asked for (the item of `.sheet(item:)`).
nonisolated struct UniverseYearRequest: Identifiable, Equatable, Sendable {
    let year: Int

    var id: Int { year }
}
