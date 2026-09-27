//
//  PlatformRulesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The bundled `PlatformRules.json` against the v6 "Create for" table.
@Suite("PlatformRules")
struct PlatformRulesTests {
    private let rules = TestData.rules

    struct Row: Sendable, CustomTestStringConvertible {
        let platform: Platform
        let aspect: AspectRatio
        let resolution: VideoResolution
        let frameRate: FrameRate
        let ideal: ClosedRange<TimeInterval>
        let minimum: TimeInterval?
        let top: Double
        let height: Double
        let width: Double

        var testDescription: String { platform.rawValue }
    }

    static let table: [Row] = [
        Row(platform: .tiktok, aspect: .portrait, resolution: .hd1080, frameRate: .fps30, ideal: 60...90, minimum: 60, top: 118, height: 280, width: 0.58),
        Row(platform: .reels, aspect: .portrait, resolution: .hd1080, frameRate: .fps30, ideal: 15...60, minimum: nil, top: 104, height: 290, width: 0.60),
        Row(platform: .shorts, aspect: .portrait, resolution: .hd1080, frameRate: .fps60, ideal: 30...60, minimum: nil, top: 104, height: 262, width: 0.60),
        Row(platform: .youtube, aspect: .landscape, resolution: .uhd4K, frameRate: .fps24, ideal: 480...900, minimum: 480, top: 104, height: 210, width: 0.70),
        Row(platform: .linkedin, aspect: .vertical, resolution: .hd1080, frameRate: .fps30, ideal: 30...90, minimum: nil, top: 196, height: 240, width: 0.64),
        Row(platform: .stories, aspect: .portrait, resolution: .hd1080, frameRate: .fps30, ideal: 8...15, minimum: nil, top: 150, height: 264, width: 0.56),
    ]

    @Test(arguments: table)
    func presetMatchesTheTable(_ row: Row) {
        let preset = rules.preset(for: row.platform, monetizationGoals: true)
        #expect(preset.aspect == row.aspect)
        #expect(preset.resolution == row.resolution)
        #expect(preset.frameRate == row.frameRate)
        #expect(preset.idealRange == row.ideal)
        #expect(preset.minimum == row.minimum)
        #expect(preset.prompter == PrompterPanelLayout(top: row.top, height: row.height, width: row.width))
    }

    @Test func withoutMonetizationTikTokAimsForFifteenToSixtySeconds() {
        let preset = rules.preset(for: .tiktok, monetizationGoals: false)
        #expect(preset.idealRange == 15...60)
        #expect(preset.minimum == nil)
        #expect(preset.goal == nil)
    }

    @Test func withoutMonetizationYouTubeAimsForFourToTenMinutes() {
        let preset = rules.preset(for: .youtube, monetizationGoals: false)
        #expect(preset.idealRange == 240...600)
        #expect(preset.minimum == nil)
    }

    @Test func monetizationGoalsNameTheirReward() {
        #expect(rules.preset(for: .tiktok, monetizationGoals: true).goal == .creatorRewards)
        #expect(rules.preset(for: .youtube, monetizationGoals: true).goal == .midRollAds)
    }

    @Test func onlyYouTubePrefersStudioAndHasNoSafeZones() {
        for platform in Platform.allCases {
            let preset = rules.preset(for: platform, monetizationGoals: true)
            #expect(preset.prefersStudio == (platform == .youtube))
            #expect(preset.showsSafeZones == (platform != .youtube))
        }
    }

    @Test func storiesAreCoveredTopAndBottom() {
        let kinds = rules.preset(for: .stories, monetizationGoals: true).safeZones.map(\.kind)
        #expect(kinds == [.profile, .replyBar])
    }

    @Test func layoutReferenceIsTheDesignScreen() {
        #expect(rules.reference.size == CGSize(width: 402, height: 874))
    }

    // MARK: - Validation

    @Test func rejectsAnotherSchema() throws {
        var other = rules
        other.schemaVersion = 2
        #expect(throws: PlatformRules.ValidationError.unsupportedSchema(2)) { try other.validate() }
    }

    @Test func rejectsAFileMissingAPlatform() {
        var partial = rules
        partial.platforms["stories"] = nil
        #expect(throws: PlatformRules.ValidationError.missingPlatform("stories")) { try partial.validate() }
    }

    @Test func rejectsAnUpsideDownRange() {
        var broken = rules
        broken.platforms["reels"]?.ideal = [60, 15]
        #expect(throws: PlatformRules.ValidationError.invalidRange("reels")) { try broken.validate() }
    }

    @Test func decodingRoundTrips() throws {
        let data = try JSONEncoder().encode(rules)
        #expect(try PlatformRules.decode(data) == rules)
    }
}
