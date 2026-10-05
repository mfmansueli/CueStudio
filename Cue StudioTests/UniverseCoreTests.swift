//
//  UniverseCoreTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// 9.2: the core's colours and where the map puts each video (the same every time, never off the board).
@MainActor
struct UniverseCoreTests {
    @Test func theFourColoursAreGoldAmberSunriseAndRose() {
        #expect(CoreColor.allCases.map(\.rawValue) == ["gold", "amber", "sunrise", "rose"])
        #expect(CoreColor.gold.stops.body == 0xFFD60A)
        #expect(CoreColor.gold.glow.hex == 0xFFD60A && CoreColor.gold.glow.opacity == 0.55)
        #expect(CoreColor.rose.glow.opacity == 0.45)
    }

    @Test func theChosenColourIsKeptOnThisIPhone() throws {
        let defaults = try #require(UserDefaults(suiteName: "UniverseCoreTests.\(UUID().uuidString)"))
        let service = PersonalizationService(defaults: defaults)
        #expect(service.coreColor == .gold)
        service.coreColor = .sunrise
        #expect(PersonalizationService(defaults: defaults).coreColor == .sunrise)
    }

    @Test func aVideosSpotIsStableAndOnTheBoard() {
        for topic in 0..<3 {
            for drawn in 0..<40 {
                let first = UniverseMap.videoSpot(topic: topic, dot: drawn, drawn: drawn)
                let again = UniverseMap.videoSpot(topic: topic, dot: drawn, drawn: drawn)
                #expect(first.offset == again.offset)
                #expect((1.6...2.4).contains(first.radius))
                let x = UniverseMap.center.x + first.offset.x
                let y = UniverseMap.center.y + first.offset.y
                #expect(x > 0 && x < UniverseMap.board.width && y > 0 && y < UniverseMap.board.height)
            }
        }
    }
}
