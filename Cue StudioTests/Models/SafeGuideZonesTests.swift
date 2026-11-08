//
//  SafeGuideZonesTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The editor's safe zone guide by the platform rules (owner, decision B, 07/11/2026): the script's platform is the suggestion,
/// Generic without one measured on the frame, the creator's pick wins while it fits the frame, an edit saved before the guide
/// shows the platform its captions were placed for, and the choice reads back from an edit (and an edit without it still opens).
@Suite("Safe zone guide")
struct SafeGuideZonesTests {
    private let zones = SafeGuideZones(rules: PlatformRulesService.bundledRules())

    @Test func eachFrameOffersTheAppsMeasuredOnItThenGeneric() {
        #expect(zones.options(for: .portrait) == [.platform(.tiktok), .platform(.reels), .platform(.shorts), .platform(.stories), .generic])
        #expect(zones.options(for: .vertical) == [.platform(.linkedin), .generic])
        #expect(zones.options(for: .square) == [.generic])
        #expect(zones.options(for: .landscape) == [.generic])
    }

    @Test func theScriptsPlatformIsTheSuggestionAndGenericWithoutOne() {
        #expect(zones.suggestion(scriptPlatform: .tiktok, aspect: .portrait) == .platform(.tiktok))
        #expect(zones.suggestion(scriptPlatform: nil, aspect: .portrait) == .generic)
        // YouTube long-form has no buttons measured; TikTok none on 4:5.
        #expect(zones.suggestion(scriptPlatform: .youtube, aspect: .portrait) == .generic)
        #expect(zones.suggestion(scriptPlatform: .tiktok, aspect: .vertical) == .generic)
    }

    @Test func thePickWinsWhileItFitsTheFrame() {
        #expect(zones.resolve(pick: .platform(.shorts), scriptPlatform: .tiktok, aspect: .portrait) == .platform(.shorts))
        #expect(zones.resolve(pick: .generic, scriptPlatform: .tiktok, aspect: .portrait) == .generic)
        // Shorts on a square frame: the suggestion there.
        #expect(zones.resolve(pick: .platform(.shorts), scriptPlatform: .tiktok, aspect: .square) == .generic)
    }

    @Test func aPlatformsMarginsAreItsMeasuredZoneAsPercentages() {
        let tiktok = zones.margins(of: .platform(.tiktok), aspect: .portrait)
        #expect(abs(tiktok.top - 160.0 / 1920 * 100) < 0.0001)
        #expect(abs(tiktok.bottom - 480.0 / 1920 * 100) < 0.0001)
        #expect(abs(tiktok.right - 140.0 / 1080 * 100) < 0.0001)
        // Measured on another frame: Generic's there.
        #expect(zones.margins(of: .platform(.tiktok), aspect: .square) == .frameEdges)
    }

    /// Generic on 9:16 is clear of every vertical app at once; where one app or none was measured, the frame's edges.
    @Test func genericIsClearOfEveryVerticalAppAndTheFramesEdgesElsewhere() {
        let generic = zones.generic(.portrait)
        for platform in [Platform.tiktok, .reels, .shorts, .stories] {
            let own = zones.margins(of: .platform(platform), aspect: .portrait)
            #expect(generic.top >= own.top && generic.bottom >= own.bottom && generic.left >= own.left && generic.right >= own.right, "\(platform)")
        }
        #expect(abs(generic.bottom - 480.0 / 1920 * 100) < 0.0001)
        #expect(abs(generic.top - 250.0 / 1920 * 100) < 0.0001)
        #expect(generic.unitContentRect.width > 0.5 && generic.unitContentRect.height > 0.5)
        #expect(zones.generic(.vertical) == .frameEdges)
        #expect(zones.generic(.square) == .frameEdges)
        #expect(zones.generic(.landscape) == .frameEdges)
    }

    /// A take with no platform got Reels' margins on 9:16 before the guide: that edit shows the Reels guide, which says the truth
    /// about where its lines sit, until the creator picks another.
    @Test func anEditSavedBeforeTheGuideShowsThePlatformItsCaptionsWerePlacedFor() {
        let reels = zones.margins(of: .platform(.reels), aspect: .portrait)
        #expect(zones.active(pick: nil, scriptPlatform: nil, aspect: .portrait, captionMargins: reels) == .platform(.reels))
        // Margins of no guide (the creator's own): the suggestion.
        let own = SafeZoneMargins(top: 3, bottom: 9, left: 4, right: 4)
        #expect(zones.active(pick: nil, scriptPlatform: nil, aspect: .portrait, captionMargins: own) == .generic)
        // A pick is a pick, whatever the margins.
        #expect(zones.active(pick: .platform(.shorts), scriptPlatform: nil, aspect: .portrait, captionMargins: reels) == .platform(.shorts))
        // A new edit: the suggestion's margins, the suggestion.
        let tiktok = zones.margins(of: .platform(.tiktok), aspect: .portrait)
        #expect(zones.active(pick: nil, scriptPlatform: .tiktok, aspect: .portrait, captionMargins: tiktok) == .platform(.tiktok))
    }

    @Test func theChoiceIsSavedAsOneWordAndAnEditWithoutItOpens() throws {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.safeGuide = .platform(.reels)
        let data = try JSONEncoder().encode(edit)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"safeGuide\":\"reels\""))
        #expect(try JSONDecoder().decode(TakeEdit.self, from: data).safeGuide == .platform(.reels))
        edit.safeGuide = .generic
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit)).safeGuide == .generic)
        // Saved before the guide, or by a version that knows a platform this one doesn't: nil, the suggestion.
        var saved = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        saved["safeGuide"] = nil
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved)).safeGuide == nil)
        saved["safeGuide"] = "threads"
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved)).safeGuide == nil)
    }
}
