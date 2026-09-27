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
    @Test func recordTabOpensStartRecordingAndKeepsTheCurrentTab() {
        let presentation = PresentationService()
        presentation.select(.takes)
        presentation.select(.record)
        #expect(presentation.selectedTab == .takes)
        #expect(presentation.sheet == .startRecording)
    }

    @Test func regularTabsChangeTheSelection() {
        let presentation = PresentationService()
        presentation.select(.profile)
        #expect(presentation.selectedTab == .profile)
        #expect(presentation.sheet == nil)
    }

    @Test func generateSheetsAreDistinctPerTab() {
        #expect(AppSheet.generateScript(.prompt).id != AppSheet.generateScript(.themes).id)
        #expect(AppSheet.generateScript(.formats) == .generateScript(.formats))
    }

    @Test func openingAScriptClosesTheSheetAndShowsScripts() {
        let presentation = PresentationService()
        presentation.select(.takes)
        presentation.present(.newScript)
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
