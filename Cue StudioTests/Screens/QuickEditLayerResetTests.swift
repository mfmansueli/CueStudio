//
//  QuickEditLayerResetTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Canvas 2 R5 (owner, 07/11/2026): Text, Graphic, Motion and Photo or video get a Reset with a defined reach. Each shows only
/// once something its panel sets differs from how the item came in, puts back only that, and is one undo step named by its kind.
@MainActor
@Suite("Quick edit · Reset in the panels of what lies on the video")
struct QuickEditLayerResetTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, toast: toast)
    }

    @Test func aTextsResetPutsBackItsLookAndKeepsWordsPlaceAndTime() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.overlays.addStyledText(.title)
        let added = try #require(viewModel.selectedText)
        #expect(viewModel.panelReset(.textStyle) == nil, "Nothing to put back on a text just added")
        viewModel.overlays.updateText(added.id) {
            $0.text = "My hook"
            $0.color = .yellow
            $0.font = .serif
            $0.center = OverlayPoint(x: 0.3, y: 0.2)
            $0.animation = OverlayAnimation(preset: .pop)
        }
        let reset = try #require(viewModel.panelReset(.textStyle))
        reset()
        let text = try #require(viewModel.selectedText)
        #expect(text.color == added.color && text.font == added.font && text.animation == nil)
        #expect(text.text == "My hook" && text.center == OverlayPoint(x: 0.3, y: 0.2) && text.span == added.span)
        #expect(viewModel.panelReset(.textStyle) == nil)
        viewModel.undo()
        #expect(viewModel.selectedText?.color == .yellow)
        #expect(scenario.toast.message == String(localized: "Undid · \(String(localized: "Text"))"))
    }

    @Test func aGraphicsResetPutsBackColorSizeAndTurn() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.overlays.addGraphic(.arrow)
        let added = try #require(viewModel.selectedText)
        #expect(viewModel.panelReset(.textStyle) == nil)
        viewModel.overlays.updateText(added.id) {
            $0.color = .red
            $0.size = TextGraphic.baseSize * 1.6
            $0.center = OverlayPoint(x: 0.7, y: 0.7)
        }
        viewModel.overlays.setGraphicRotation(added.id, degrees: 45)
        let reset = try #require(viewModel.panelReset(.textStyle))
        reset()
        let graphic = try #require(viewModel.selectedText)
        #expect(graphic.color == CoverItemKind.arrow.defaultColor && graphic.size == TextGraphic.baseSize)
        #expect(graphic.graphic?.rotation == 0 && graphic.center == OverlayPoint(x: 0.7, y: 0.7))
    }

    @Test func styleForEveryTextHasNoTextReset() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.overlays.addStyledText(.title)
        let added = try #require(viewModel.selectedText)
        viewModel.overlays.updateText(added.id) { $0.color = .yellow }
        viewModel.overlays.textStyleScope = .allTexts
        #expect(viewModel.panelReset(.textStyle) == nil, "One text's Reset must not show while styling every text")
    }

    @Test func motionsResetTakesTheWayInAndTheKeyframesOff() async throws {
        let viewModel = await makeScenario().viewModel
        var media = MediaOverlay(kind: .photo, fileName: "logo.png", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 2, end: 6))
        viewModel.change { $0.media = [media] }
        viewModel.selection = .media(media.id)
        #expect(viewModel.panelReset(.motion) == nil)
        media.animation = OverlayAnimation(preset: .fade)
        media.keyframes = [OverlayKeyframe(time: 0, center: .center), OverlayKeyframe(time: 1, center: OverlayPoint(x: 0.2, y: 0.2))]
        let moving = media
        viewModel.overlays.updateMedia(media.id) { $0 = moving }
        let reset = try #require(viewModel.panelReset(.motion))
        reset()
        #expect(viewModel.edit.media[0].animation == nil && (viewModel.edit.media[0].keyframes ?? []).isEmpty)
        #expect(viewModel.edit.media[0].span == media.span)
    }

    @Test func aPhotoOrVideosResetKeepsHowItShowsAndItsPart() async throws {
        let viewModel = await makeScenario().viewModel
        var media = MediaOverlay(kind: .video, fileName: "broll.mov", aspect: 1, mediaDuration: 8, span: TimeSpan(start: 2, end: 6))
        media.layout = .window
        viewModel.change { $0.media = [media] }
        viewModel.selection = .media(media.id)
        #expect(viewModel.panelReset(.media) == nil)
        viewModel.overlays.updateMedia(media.id) {
            $0.shape = .square
            $0.width = 0.35
            $0.opacity = 0.5
        }
        let reset = try #require(viewModel.panelReset(.media))
        reset()
        let item = viewModel.edit.media[0]
        #expect(item.shape == media.shape && item.width == media.width && item.opacity == nil)
        #expect(item.layout == .window && item.span == media.span)
    }

    /// R5: in a split screen, Center and fill puts back only the area's framing (fit, zoom, center), never the support's sound,
    /// motion, time or the layout, nor anything of the main video's.
    @Test func centerAndFillTouchesOnlyTheFraming() async throws {
        let viewModel = await makeScenario().viewModel
        var support = MediaOverlay(kind: .video, fileName: "screen.mov", aspect: 0.5, mediaDuration: 8, span: TimeSpan(start: 0, end: 8))
        support.layout = .split
        support.hasSound = true
        support.audioVolume = 0.4
        support.animation = OverlayAnimation(preset: .fade)
        support.areaFraming = AreaFraming(fit: .fit, zoom: 2, center: OverlayPoint(x: 0.3, y: 0.6))
        viewModel.change { $0.media = [support] }
        viewModel.selection = .media(support.id)
        viewModel.overlays.setAreaFraming(AreaFraming(fit: .fill, zoom: 1.6, center: OverlayPoint(x: 0.4, y: 0.4)), for: .main, of: support.id)
        let before = viewModel.edit
        viewModel.overlays.setAreaFraming(AreaFraming(), for: .support, of: support.id)
        var expected = before.media[0]
        expected.areaFraming = AreaFraming()
        #expect(viewModel.edit.media[0] == expected)
        #expect(viewModel.edit.splitScreen == before.splitScreen && viewModel.edit.timeline == before.timeline)
        let supportDone = viewModel.edit
        viewModel.overlays.setAreaFraming(AreaFraming(), for: .main, of: support.id)
        #expect(viewModel.edit.media == supportDone.media && viewModel.edit.timeline == supportDone.timeline)
        #expect(viewModel.edit.texts == supportDone.texts && viewModel.edit.music == supportDone.music)
    }
}
