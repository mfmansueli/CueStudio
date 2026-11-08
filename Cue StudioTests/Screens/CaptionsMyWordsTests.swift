//
//  CaptionsMyWordsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// My words from the editor (`CaptionsViewModel+MyWords`): the sheet opens from Captions, a word is added, respelled and
/// deleted in the store the recognizers read; Find and replace's Add to my words saves the spelling it shows and changes no
/// caption, and Replace never saves a word.
@MainActor
@Suite("Captions › My words")
struct CaptionsMyWordsTests {
    let host: FakeEditorHost
    let store: FakeMyWordsStore
    let part: CaptionsViewModel

    init() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.captions = [
            CaptionCue(words: [
                CaptionWord(text: "I", start: 1, end: 1.2), CaptionWord(text: "love", start: 1.3, end: 1.6),
                CaptionWord(text: "tick", start: 1.7, end: 1.9), CaptionWord(text: "tock", start: 2, end: 2.3),
            ]),
            CaptionCue(text: "See you on tick tock", start: 4, end: 6),
        ]
        edit.showsCaptions = true
        host = FakeEditorHost(edit: edit)
        store = FakeMyWordsStore(["CapCut"])
        part = CaptionsViewModel(
            session: host.session, editing: FakeTakeEditor(),
            takes: TakeLibraryService(repository: FakeTakeRepository(takes: [])),
            library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])),
            styles: FakeTextStyleStore(), myWords: store, translations: FakeTranslationAvailability(),
            speechLanguage: { _ in .language(.english) }, likelySpokenLanguages: { _ in [] }, languageConflict: { _ in nil }
        )
    }

    @Test func myWordsOpensOverTheEditorWithTheSavedList() {
        store.words = MyWordsList(["TikTok", "CapCut"])
        part.openMyWords()
        #expect(host.sheet == .myWords)
        #expect(part.myWords.words == ["TikTok", "CapCut"])
    }

    @Test func aWordIsAddedChangedAndDeletedInTheStore() {
        #expect(part.addToMyWords("iPhone") == .added("iPhone"))
        #expect(store.words.words == ["iPhone", "CapCut"])
        #expect(part.myWords == store.words)
        #expect(part.addToMyWords("iphone") == .respelled("iphone"))
        #expect(part.changeMyWord("iphone", to: "iPhone"))
        #expect(!part.changeMyWord("iPhone", to: " "))
        #expect(store.words.words == ["iPhone", "CapCut"])
        part.deleteMyWords(atOffsets: IndexSet(integer: 1))
        #expect(store.words.words == ["iPhone"])
        part.deleteMyWord("iPhone")
        #expect(store.words.isEmpty)
    }

    @Test func aWordAlreadyThereWritesNothing() {
        let writes = store.writes
        #expect(part.addToMyWords("CapCut") == .alreadyThere("CapCut"))
        #expect(part.addToMyWords("   ") == .invalid)
        #expect(store.writes == writes)
    }

    @Test func findSavesReplaceWithsSpellingElseFinds() {
        #expect(part.myWordsSpelling(find: "tick tock", replacement: " TikTok ") == "TikTok")
        #expect(part.myWordsSpelling(find: " Notion ", replacement: "") == "Notion")
        #expect(part.myWordsSpelling(find: "", replacement: "  ") == nil)
        #expect(part.myWordsSpelling(find: String(repeating: "a", count: MyWordsList.longest + 1), replacement: "") == nil)
        #expect(part.isInMyWords("CapCut"))
        #expect(!part.isInMyWords("capcut"), "Other capitals would still be saved")
    }

    @Test func addToMyWordsSavesTheShownSpellingAndChangesNoCaption() throws {
        let captions = host.document.edit.captions
        let steps = host.document.history.past.count
        let spelling = try #require(part.myWordsSpelling(find: "tick tock", replacement: "TikTok"))
        part.addFindSpellingToMyWords(spelling)
        #expect(store.words.words == ["TikTok", "CapCut"])
        #expect(host.document.edit.captions == captions)
        #expect(host.document.history.past.count == steps, "Saving a word is no change to the video")
        #expect(host.session.toast.message == "“TikTok” added to My words")
    }

    @Test func replaceNeverSavesAWord() {
        let writes = store.writes
        #expect(part.replaceAllCaptionMatches("tick tock", with: "TikTok") == 2)
        #expect(host.document.edit.captions.map(\.text) == ["I love TikTok", "See you on TikTok"])
        let match = part.captionMatches(for: "TikTok")[0]
        part.replaceCaptionMatch(match, query: "TikTok", with: "Tiktok")
        #expect(store.writes == writes)
        #expect(store.words.words == ["CapCut"])
    }

    @Test func aFullListSaysSo() {
        store.words = MyWordsList((1...MyWordsList.limit).map { "Name\($0)" })
        part.addFindSpellingToMyWords("TikTok")
        #expect(store.words.count == MyWordsList.limit)
        #expect(!store.words.words.contains("TikTok"))
        #expect(host.session.toast.kind == .problem)
    }
}
