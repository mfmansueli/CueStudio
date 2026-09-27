//
//  PlatformRulesFetching.swift
//  Cue Studio
//

import Foundation

/// Downloads a newer copy of the platform rules. Swappable so tests never touch the network.
protocol PlatformRulesFetching {
    func fetchRules(from url: URL) async throws -> Data
}
