//
//  SettingsSearchTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Settings' search finds the rows themselves, grouped by where they live.
@Suite("Settings search")
struct SettingsSearchTests {
    @Test func mirrorFindsTheRigsRows() {
        let groups = SettingsSearchGroup.results(for: "mirror")
        let rigs = groups.first { $0.entries.contains(.mirrorText) }
        #expect(rigs?.entries == [.mirrorText, .flipVertically])
        #expect(rigs?.path.hasSuffix("Rigs") == true)
    }

    @Test func aWordThatMatchesNothingFindsNothing() {
        #expect(SettingsSearchGroup.results(for: "zzzz").isEmpty)
        #expect(SettingsSearchGroup.results(for: "   ").isEmpty)
    }

    @Test func caseAndAccentsAreIgnored() {
        #expect(SettingsSearchGroup.results(for: "SPEED").flatMap(\.entries).contains(.speed))
        #expect(SettingsSearchGroup.results(for: "ténor").isEmpty)
        #expect(SettingsSearchGroup.results(for: "mírror").flatMap(\.entries).contains(.mirrorText))
    }

    @Test func everyWordHasToMatch() {
        let entries = SettingsSearchGroup.results(for: "text size").flatMap(\.entries)
        #expect(entries.contains(.textSize))
        #expect(!entries.contains(.speed))
    }

    @Test func aRowThatIsNotShownIsNotFound() {
        let all = SettingsSearchGroup.results(for: "privacy policy").flatMap(\.entries)
        let hidden = SettingsSearchGroup.results(for: "privacy policy") { $0 != .privacyPolicy }.flatMap(\.entries)
        #expect(all.contains(.privacyPolicy))
        #expect(!hidden.contains(.privacyPolicy))
    }

    @Test func resultsKeepThePageOrderAndEveryRowHasWords() {
        let order = SettingsEntry.allCases
        let found = SettingsSearchGroup.results(for: "camera").flatMap(\.entries)
        #expect(found.count > 1)
        #expect(found.map { order.firstIndex(of: $0) ?? 0 }.isSorted)
        for entry in SettingsEntry.allCases {
            #expect(!entry.title.isEmpty)
            #expect(!entry.path.isEmpty)
            #expect(!entry.keywords.isEmpty)
        }
    }

    @Test func theTextSizeSegmentsAreSmallMediumLargeAndXL() {
        #expect(PrompterTextSize.allCases.map(\.shortLabel) == ["Small", "Medium", "Large", "XL"])
        #expect(PrompterTextSize.nearest(to: 40) == .large)
        #expect(PrompterTextSize.nearest(to: 17) == .small)
        #expect(PrompterTextSize.nearest(to: 56) == .extraLarge)
    }
}

private extension Sequence where Element: Comparable {
    var isSorted: Bool { zip(self, dropFirst()).allSatisfy { $0 <= $1 } }
}
