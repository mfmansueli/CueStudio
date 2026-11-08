//
//  QuickEditSafeGuideTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The safe zone guide in the editor (owner, decision B, 07/11/2026): showing it is the creator's way of working, kept for every
/// video and never an undo step nor a change to save; switching its app is this video's choice, one undo step that moves the
/// captions to that app's clear area with it (the file places them the same: `SafeGuideExportTests`). It opens on the script's
/// platform, Generic without one, and keeps the pick across a change of shape.
@MainActor
@Suite("Quick edit safe zone guide")
struct QuickEditSafeGuideTests {
    private func makeEditor(platform: Platform? = .tiktok, preferences: FakeEditorPreferencesStore = FakeEditorPreferencesStore()) async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 1)
        take.platform = platform
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), editorPreferences: preferences
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func showingTheGuideIsKeptForEveryVideoAndChangesNothingInThisOne() async {
        let preferences = FakeEditorPreferencesStore()
        let viewModel = await makeEditor(preferences: preferences)
        #expect(!viewModel.look.showsSafeGuide)
        #expect(!viewModel.showsSafeGuideOverlay)
        viewModel.look.setShowsSafeGuide(true)
        #expect(preferences.showsSafeGuide)
        #expect(viewModel.showsSafeGuideOverlay)
        #expect(!viewModel.canUndo)
        #expect(!viewModel.hasUnsavedChanges)
        // The next video opens with it on.
        let next = await makeEditor(preferences: preferences)
        #expect(next.look.showsSafeGuide)
        next.look.setShowsSafeGuide(false)
        #expect(!preferences.showsSafeGuide)
    }

    @Test func itOpensOnTheScriptsPlatformAndGenericWithoutOne() async {
        let tiktok = await makeEditor(platform: .tiktok)
        #expect(tiktok.look.safeGuide == .platform(.tiktok))
        #expect(tiktok.look.suggestedSafeGuide == .platform(.tiktok))
        #expect(tiktok.edit.captionCollection?.safeMargins == CaptionSafeArea.zones.margins(of: .platform(.tiktok), aspect: .portrait))
        let none = await makeEditor(platform: nil)
        #expect(none.look.safeGuide == .generic)
        #expect(none.edit.captionCollection?.safeMargins == CaptionSafeArea.zones.generic(.portrait))
        #expect(none.look.safeGuideNote != tiktok.look.safeGuideNote)
        // YouTube long-form has no buttons measured on 9:16.
        let youtube = await makeEditor(platform: .youtube)
        #expect(youtube.look.safeGuide == .generic)
    }

    @Test func switchingTheAppMovesTheCaptionsInOneUndoStep() async throws {
        let viewModel = await makeEditor()
        let tiktok = try #require(viewModel.edit.captionCollection?.safeMargins)
        let before = viewModel.edit
        viewModel.look.pickSafeGuide(.platform(.stories))
        #expect(viewModel.look.showsSafeGuide, "picking an app shows its guide")
        #expect(viewModel.edit.safeGuide == .platform(.stories))
        let stories = CaptionSafeArea.zones.margins(of: .platform(.stories), aspect: .portrait)
        #expect(viewModel.edit.captionCollection?.safeMargins == stories)
        #expect(stories != tiktok)
        #expect(viewModel.hasUnsavedChanges)
        #expect(EditStepSummary(from: before, to: viewModel.edit).name == String(localized: "Safe zones"))
        viewModel.undo()
        #expect(viewModel.edit.safeGuide == nil)
        #expect(viewModel.edit.captionCollection?.safeMargins == tiktok)
        #expect(viewModel.look.showsSafeGuide, "Undo takes back the app, not the switch that shows the guide")
        viewModel.redo()
        #expect(viewModel.edit.captionCollection?.safeMargins == stories)
        // The one shown already, or one the frame doesn't have: nothing to undo.
        viewModel.look.pickSafeGuide(.platform(.stories))
        viewModel.look.pickSafeGuide(.platform(.linkedin))
        viewModel.undo()
        #expect(viewModel.edit.safeGuide == nil)
    }

    @Test func thePickStaysThisVideosAcrossAChangeOfShape() async {
        let viewModel = await makeEditor()
        viewModel.look.pickSafeGuide(.platform(.shorts))
        let shorts = CaptionSafeArea.zones.margins(of: .platform(.shorts), aspect: .portrait)
        viewModel.look.setAspect(.square)
        #expect(viewModel.look.safeGuide == .generic)
        #expect(viewModel.look.safeGuideOptions == [.generic])
        #expect(viewModel.edit.captionCollection?.safeMargins == .frameEdges)
        viewModel.look.setAspect(.portrait)
        #expect(viewModel.look.safeGuide == .platform(.shorts))
        #expect(viewModel.edit.captionCollection?.safeMargins == shorts)
        viewModel.look.setAspect(.vertical)
        viewModel.look.resetFormat()
        #expect(viewModel.edit.captionCollection?.safeMargins == shorts)
    }

    /// The line the guide draws is the edge the captions keep to: the same margins, mapped on the preview.
    @Test func theGuidesRectIsTheCaptionsClearArea() async throws {
        let viewModel = await makeEditor()
        viewModel.look.pickSafeGuide(.platform(.reels))
        let size = CGSize(width: 270, height: 480)
        let rect = viewModel.look.safeGuideRect(in: size)
        #expect(rect == viewModel.overlays.safeArea(in: size))
        let reels = try #require(PlatformRulesService.bundledRules().safeZone(for: .reels))
        #expect(abs(rect.minY - reels.top / reels.videoHeight * size.height) < 0.001)
        #expect(abs(rect.maxY - (1 - reels.bottom / reels.videoHeight) * size.height) < 0.001)
        #expect(abs(rect.maxX - (1 - reels.right / reels.videoWidth) * size.width) < 0.001)
    }

    @Test func theGuideIsOffTheFullScreen() async {
        let viewModel = await makeEditor()
        viewModel.look.setShowsSafeGuide(true)
        viewModel.toggleFullScreen()
        #expect(!viewModel.showsSafeGuideOverlay)
    }
}
