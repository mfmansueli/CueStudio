//
//  MyWordsStoreTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// My words on this iPhone: kept between launches under their own key (never the AI writing profile's), read the same by every
/// store on the same defaults, and an unreadable value read as an empty list.
@MainActor
@Suite("My words store")
struct MyWordsStoreTests {
    @Test func wordsAreKeptBetweenLaunches() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = MyWordsStore(defaults: defaults.defaults)
        #expect(store.words.isEmpty)
        var list = store.words
        list.add("iPhone")
        list.add("TikTok")
        store.words = list
        // Another store on the same defaults (the recognizers', the next launch's) reads the same list.
        #expect(MyWordsStore(defaults: defaults.defaults).words.words == ["TikTok", "iPhone"])
        #expect(defaults.defaults.stringArray(forKey: DefaultsKey.myWords) == ["TikTok", "iPhone"])
    }

    @Test func anEmptiedListLeavesNothingBehind() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = MyWordsStore(defaults: defaults.defaults)
        store.words = MyWordsList(["Acme"])
        store.words = MyWordsList()
        #expect(defaults.defaults.object(forKey: DefaultsKey.myWords) == nil)
    }

    @Test func anUnreadableValueReadsAsAnEmptyList() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        defaults.defaults.set(Data("not a list".utf8), forKey: DefaultsKey.myWords)
        #expect(MyWordsStore(defaults: defaults.defaults).words.isEmpty)
        defaults.defaults.set("TikTok", forKey: DefaultsKey.myWords)
        #expect(MyWordsStore(defaults: defaults.defaults).words.isEmpty)
        // A list with other things in it keeps only the words it can add.
        defaults.defaults.set(["TikTok", 3, "", "tiktok", String(repeating: "x", count: 99)] as [Any], forKey: DefaultsKey.myWords)
        #expect(MyWordsStore(defaults: defaults.defaults).words.words == ["TikTok"])
    }

    @Test func myWordsAreNotTheWritingProfile() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let before = profile.profile
        MyWordsStore(defaults: defaults.defaults).words = MyWordsList(["Giancarlo"])
        #expect(CreatorProfileService(defaults: defaults.defaults).profile == before)
        #expect(DefaultsKey.myWords != DefaultsKey.creatorProfile)
    }
}
