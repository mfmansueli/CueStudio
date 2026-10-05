//
//  FormatChoiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("FormatChoice")
struct FormatChoiceTests {
    @Test func theGridHasNineTilesInOrder() {
        #expect(FormatChoice.gridTiles == [
            .auto, .talkingHead, .type(.tutorial), .type(.story), .type(.list), .type(.review),
            .type(.mythFact), .type(.pov), .type(.ad),
        ])
    }

    @Test func moreFormatsListsEveryOtherTypeInTheEnumsOrder() {
        #expect(FormatChoice.moreFormats == [.type(.opinion), .type(.launch), .type(.apology)])
        #expect(Set(FormatChoice.allTiles.compactMap(\.scriptType)) == Set(ScriptType.allCases))
        #expect(FormatChoice.allTiles.count == 12)
    }

    @Test func noFormatIsLost() {
        // Every format that existed before v29 is still a choice: a tile or a row under "More formats".
        for type in [ScriptType.ad, .review, .tutorial, .list, .story, .opinion, .launch, .apology] {
            #expect(FormatChoice.allTiles.contains(.type(type)), "\(type) has no tile")
        }
    }

    @Test func autoAndTalkingHeadHaveNoTypeOfTheirOwn() {
        #expect(FormatChoice.auto.scriptType == nil)
        #expect(FormatChoice.talkingHead.scriptType == nil)
        #expect(FormatChoice(nil) == .auto)
        #expect(FormatChoice(.pov) == .type(.pov))
    }

    @Test func eachTileShowsItsSections() {
        #expect(FormatChoice.talkingHead.sections == ["Hook", "Point", "Why it matters", "CTA"])
        #expect(FormatChoice.type(.mythFact).sections == ["Myth", "Why people think it", "Fact", "CTA"])
        #expect(FormatChoice.type(.pov).sections == ["POV line", "Scene", "Twist"])
        #expect(FormatChoice.auto.sections == ["Hook", "Body", "CTA"])
    }

    @Test func onlyTheSponsoredAdNeedsABrandBrief() {
        #expect(FormatChoice.allTiles.filter(\.needsBrandBrief) == [.type(.ad)])
    }

    @Test func anApologyIsSerious() {
        #expect(FormatChoice.type(.apology).isSerious)
        #expect(!FormatChoice.type(.ad).isSerious)
    }
}
