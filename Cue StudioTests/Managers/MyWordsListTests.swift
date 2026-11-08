//
//  MyWordsListTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// My words as a list: saved as typed, newest first, one entry per word (capitals aside, accents not), at most `limit`, and
/// nothing empty or longer than `longest`.
@Suite("My words list")
struct MyWordsListTests {
    @Test func aWordIsSavedAsTypedAtTheTop() {
        var list = MyWordsList()
        #expect(list.add("  iPhone ") == .added("iPhone"))
        #expect(list.add("“TikTok”") == .added("TikTok"))
        #expect(list.add("Cue   Studio") == .added("Cue Studio"))
        #expect(list.words == ["Cue Studio", "TikTok", "iPhone"])
    }

    @Test func theSameWordIsKeptOnceAndOtherCapitalsRespellIt() {
        var list = MyWordsList(["TikTok"])
        #expect(list.add("TikTok") == .alreadyThere("TikTok"))
        #expect(list.add("Tiktok") == .respelled("Tiktok"))
        #expect(list.words == ["Tiktok"])
        // Full-width letters are the same word; an accent makes another one.
        #expect(list.add("ＴｉｋＴｏｋ") == .respelled("ＴｉｋＴｏｋ"))
        #expect(list.count == 1)
        var accents = MyWordsList(["cafe"])
        #expect(accents.add("café") == .added("café"))
        #expect(accents.count == 2)
    }

    @Test func emptyAndTooLongTextIsNeverSaved() {
        var list = MyWordsList()
        #expect(list.add("   ") == .invalid)
        #expect(list.add("\"\"") == .invalid)
        #expect(list.add(String(repeating: "a", count: MyWordsList.longest + 1)) == .invalid)
        #expect(list.add(String(repeating: "a", count: MyWordsList.longest)) == .added(String(repeating: "a", count: MyWordsList.longest)))
        #expect(list.count == 1)
    }

    @Test func theListStopsAtItsLimit() {
        var list = MyWordsList((1...MyWordsList.limit).map { "Name\($0)" })
        #expect(list.count == MyWordsList.limit)
        #expect(list.add("OneMore") == .full)
        #expect(list.count == MyWordsList.limit)
        // A word already there still takes new capitals when full.
        #expect(list.add("NAME1") == .respelled("NAME1"))
        // A damaged list reads at most the limit, without repeats or empty entries.
        let read = MyWordsList(["", "Acme", "acme"] + (1...80).map { "Word\($0)" })
        #expect(read.count == MyWordsList.limit)
        #expect(read.words.first == "Acme")
        #expect(!read.words.contains("acme") && !read.words.contains(""))
    }

    @Test func aWordIsChangedInItsPlaceAndDeleted() {
        var list = MyWordsList(["CapCut", "Notion", "TikTok"])
        #expect(list.change("Notion", to: "Notion AI") == "Notion AI")
        #expect(list.words == ["CapCut", "Notion AI", "TikTok"])
        // Changed into another entry's word, the two become one.
        #expect(list.change("CapCut", to: "tiktok") == "tiktok")
        #expect(list.words == ["Notion AI", "tiktok"])
        #expect(list.change("Notion AI", to: "  ") == nil)
        #expect(list.change("Missing", to: "Other") == nil)
        list.remove("tiktok")
        #expect(list.words == ["Notion AI"])
        list.remove(atOffsets: IndexSet(integer: 0))
        #expect(list.isEmpty)
    }

    @Test func anEntryIsFoundWhateverItsCapitals() {
        let list = MyWordsList(["YouTube"])
        #expect(list.entry(matching: "youtube") == "YouTube")
        #expect(list.entry(matching: "you tube") == nil)
    }
}
