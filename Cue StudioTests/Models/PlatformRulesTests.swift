//
//  PlatformRulesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The bundled `PlatformRules.json` against the "Create for" table and the v7 safe zones.
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
        /// Top, bottom, left, right in pixels of the video; nil for none.
        let zone: [Double]?

        var testDescription: String { platform.rawValue }
    }

    static let table: [Row] = [
        Row(platform: .tiktok, aspect: .portrait, resolution: .hd1080, frameRate: .fps30, ideal: 60...90, minimum: 60, zone: [160, 480, 60, 140]),
        Row(platform: .reels, aspect: .portrait, resolution: .hd1080, frameRate: .fps30, ideal: 30...90, minimum: nil, zone: [220, 420, 60, 120]),
        Row(platform: .shorts, aspect: .portrait, resolution: .hd1080, frameRate: .fps60, ideal: 30...60, minimum: nil, zone: [190, 380, 60, 140]),
        Row(platform: .youtube, aspect: .landscape, resolution: .uhd4K, frameRate: .fps24, ideal: 480...900, minimum: 480, zone: nil),
        Row(platform: .linkedin, aspect: .vertical, resolution: .hd1080, frameRate: .fps30, ideal: 30...90, minimum: nil, zone: [0, 200, 40, 40]),
        Row(platform: .stories, aspect: .portrait, resolution: .hd1080, frameRate: .fps30, ideal: 15...30, minimum: nil, zone: [250, 250, 60, 60]),
    ]

    @Test(arguments: table)
    func presetMatchesTheTable(_ row: Row) {
        let preset = rules.preset(for: row.platform, monetizationGoals: true)
        #expect(preset.aspect == row.aspect)
        #expect(preset.resolution == row.resolution)
        #expect(preset.frameRate == row.frameRate)
        #expect(preset.idealRange == row.ideal)
        #expect(preset.minimum == row.minimum)
        #expect(preset.safeZone.map { [$0.top, $0.bottom, $0.left, $0.right] } == row.zone)
    }

    @Test func withoutMonetizationTikTokAimsForHalfAMinuteToAMinuteAndAHalf() {
        let preset = rules.preset(for: .tiktok, monetizationGoals: false)
        #expect(preset.idealRange == 30...90)
        #expect(preset.minimum == nil)
        #expect(preset.goal == nil)
    }

    /// Everything Cue makes is spoken to the camera (revision 3 of the rules, from the research of 6 Oct 2026: talking-head Reels do best at 45–75 s,
    /// educational TikToks at 30–90 s, spoken Shorts at 30–60 s, LinkedIn at 30–90 s): a few words and a hook are not a spoken video, so no short-form
    /// platform goes below 30 s, and a Story, which is a card of at most a minute, below 15.
    @Test func aSpokenVideoNeedsMoreThanFifteenSecondsOnEveryPlatform() {
        for platform in Platform.allCases {
            for monetization in [true, false] {
                let ideal = rules.preset(for: platform, monetizationGoals: monetization).idealRange
                let floor: TimeInterval = platform == .stories ? 15 : 30
                #expect(ideal.lowerBound >= floor, "\(platform) \(monetization): \(ideal)")
                // Enough to say something: at 150 words a minute the shortest is 37 words for a Story and 75 for the rest.
                #expect(ReadTime.words(for: ideal.lowerBound) >= (platform == .stories ? 35 : 70), "\(platform)")
            }
        }
        #expect(rules.preset(for: .reels, monetizationGoals: true).idealRange == 30...90)
        #expect(rules.preset(for: .stories, monetizationGoals: true).idealRange == 15...30)
    }

    @Test func theRulesOfThisBuildAreNewerThanTheOnesThatCameBefore() {
        #expect(rules.revision >= 3, "a cached file of revision 2 (15 s Reels) must not win over the bundled one")
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

    @Test func safeZonesAreMeasuredOnTheExportedFrame() {
        for platform in Platform.allCases {
            guard let zone = rules.safeZone(for: platform) else { continue }
            #expect(zone.aspect == rules.preset(for: platform, monetizationGoals: true).aspect)
            #expect(zone.videoWidth == 1080)
            #expect(zone.videoHeight == (zone.aspect == .vertical ? 1350 : 1920))
            #expect(zone.isValid)
        }
    }

    // MARK: - Validation

    @Test func rejectsAnotherSchema() throws {
        var other = rules
        other.schemaVersion = 1
        #expect(throws: PlatformRules.ValidationError.unsupportedSchema(1)) { try other.validate() }
    }

    @Test func rejectsASafeZoneThatCoversTheWholeFrame() {
        var broken = rules
        broken.platforms["reels"]?.safeZone?.top = 1000
        broken.platforms["reels"]?.safeZone?.bottom = 1000
        #expect(throws: PlatformRules.ValidationError.invalidSafeZone("reels")) { try broken.validate() }
    }

    @Test func rejectsASafeZoneMeasuredOnAnotherFrame() {
        var broken = rules
        broken.platforms["linkedin"]?.safeZone?.aspect = .portrait
        #expect(throws: PlatformRules.ValidationError.invalidSafeZone("linkedin")) { try broken.validate() }
    }

    @Test func aV6RulesFileNoLongerDecodes() {
        let v6 = #"{"schemaVersion":1,"revision":9,"reference":{"width":402,"height":874},"platforms":{}}"#
        #expect(throws: (any Error).self) { try PlatformRules.decode(Data(v6.utf8)) }
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
