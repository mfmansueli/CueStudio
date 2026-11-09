//
//  PresentationServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("PresentationService")
struct PresentationServiceTests {
    @Test(arguments: [AppTab.scripts, .takes, .profile, .settings])
    func recordTabOpensStartRecordingAndKeepsTheCurrentTab(tab: AppTab) {
        let presentation = PresentationService()
        presentation.select(tab)
        presentation.select(.record)
        #expect(presentation.selectedTab == tab)
        #expect(presentation.sheet == .startRecording)
    }

    @Test(arguments: [AppTab.scripts, .takes, .profile, .settings])
    func regularTabsChangeTheSelection(tab: AppTab) {
        let presentation = PresentationService()
        presentation.select(tab)
        #expect(presentation.selectedTab == tab)
        #expect(presentation.sheet == nil)
    }

    /// B18: a notification about the take whose review is already on screen (its export finished, its queue's turn) doesn't open it a
    /// second time, which came back after the creator closed it; another take's review, or one asked to do something else, still opens.
    @Test func aNotificationForTheReviewOnScreenDoesNotOpenItAgain() {
        let presentation = PresentationService()
        let take = TestData.take(scriptID: UUID())
        presentation.reviewOnScreen = take.id
        presentation.openReview(of: take)
        presentation.openReview(of: take, then: .continueQueue)
        #expect(presentation.prompter == nil)
        presentation.openReview(of: take, then: .edit)
        #expect(presentation.prompter?.reviewAction == .edit)
        presentation.prompter = nil
        presentation.reviewOnScreen = nil
        presentation.openReview(of: take)
        #expect(presentation.prompter?.reviewTakeID == take.id)
    }

    @Test func theIdeaCardsSheetsAreDistinct() {
        let sheets: [AppSheet] = [.ideas, .format, .createFor]
        #expect(Set(sheets.map(\.id)).count == 3)
    }

    @Test func writingAnIdeaOpensTheScriptInTheDraftWithTheRequest() {
        let presentation = PresentationService()
        presentation.present(.ideas)
        let id = UUID()
        let request = ScriptRequest(source: .prompt("Carnival"), platform: .reels, voice: nil, targetRange: 30...60)
        presentation.openScript(id, writing: request)
        #expect(presentation.sheet == nil)
        #expect(presentation.scriptsPath == [ScriptRoute(scriptID: id, startsEditing: true, writing: request)])
    }

    @Test func openingAScriptClosesTheSheetAndShowsScripts() {
        let presentation = PresentationService()
        presentation.select(.takes)
        presentation.present(.newScript())
        let id = UUID()
        presentation.openScript(id, editing: true)
        #expect(presentation.sheet == nil)
        #expect(presentation.selectedTab == .scripts)
        #expect(presentation.scriptsPath == [ScriptRoute(scriptID: id, startsEditing: true)])
    }

    @Test func openingThePrompterClosesTheSheet() {
        let presentation = PresentationService()
        presentation.present(.startRecording)
        presentation.openPrompter(scriptID: nil, mode: .selfie)
        #expect(presentation.sheet == nil)
        #expect(presentation.prompter?.scriptID == nil)
        #expect(presentation.prompter?.mode == .selfie)
    }
}
