//
//  TimelineDrawingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The timeline draws again only what changed (`TimelineContentView`): a frame or waveform arriving, a scroll that needs a new
/// window, or another clip picked keeps every layer whose drawing didn't change, so a long captioned take stays light to
/// redraw. Prints (and attaches) a "TIMELINE …" line with how long a redraw takes.
@MainActor
@Suite("Quick edit: the timeline keeps what didn't change")
struct TimelineDrawingTests {
    @MainActor
    private struct Scene {
        let viewModel: QuickEditViewModel
        let content: TimelineContentView
        let sources: TimelineContentView.Sources

        var layers: [CALayer] { content.layer.sublayers?.first?.sublayers ?? [] }

        func show() {
            content.show(TimelineGeometry(viewModel.timelineInput(heightClass: .regular)), sources: sources)
        }
    }

    /// Ten minutes in three clips, a line every three seconds, a text every thirty, music; seen around the middle.
    private func makeScene() async throws -> Scene {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 600
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 600
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit { edit in
            edit.captions = (0..<200).map { CaptionCue(text: "Line \($0) of the take", start: Double($0) * 3, end: Double($0) * 3 + 2.5) }
            edit.showsCaptions = true
            _ = edit.timeline.split(atEdited: 200)
            _ = edit.timeline.split(atEdited: 400)
        }
        for index in 0..<20 {
            player.seek(to: Double(index) * 30)
            viewModel.overlays.addText(.title)
        }
        viewModel.selection = nil
        player.seek(to: 300)
        let content = TimelineContentView(frame: CGRect(x: 0, y: 0, width: 600 * 44, height: 260))
        let sources = TimelineContentView.Sources(take: URL.temporaryDirectory.appending(path: "none.mov"))
        let scene = Scene(viewModel: viewModel, content: content, sources: sources)
        scene.show()
        content.scrolled(to: CGRect(x: 300 * 44 - 200, y: 0, width: 400, height: 260))
        return scene
    }

    @Test func aRedrawKeepsEveryLayerWhoseDrawingDidntChange() async throws {
        let scene = try await makeScene()
        let before = scene.layers
        #expect(before.count > 20)
        let start = ProcessInfo.processInfo.systemUptime
        let rounds = 20
        for _ in 0..<rounds { scene.content.redraw() }
        let perRedraw = (ProcessInfo.processInfo.systemUptime - start) / Double(rounds)
        let after = scene.layers
        let kept = Set(after.map(ObjectIdentifier.init)).intersection(before.map(ObjectIdentifier.init)).count
        let line = "TIMELINE redraw · \(before.count) layers · \(String(format: "%.2f ms", perRedraw * 1000)) a redraw · \(kept) kept"
        print(line)
        Attachment.record(line, named: "timeline-redraw.txt")
        #expect(kept == before.count)
    }

    @Test func newWordsOnATextRedrawOnlyItsBar() async throws {
        let scene = try await makeScene()
        let before = Set(scene.layers.map(ObjectIdentifier.init))
        let index = try #require(scene.viewModel.edit.texts.firstIndex { abs($0.span.start - 300) < 1 })
        scene.viewModel.changeEdit { $0.texts[index].text = "New words" }
        scene.show()
        let after = scene.layers
        #expect(after.count == before.count)
        #expect(after.filter { !before.contains(ObjectIdentifier($0)) }.count == 1)
    }

    /// Picking a clip changes the clips (the picked one framed, its handles) and dims the other tracks: those are drawn again,
    /// the ruler, the cover, the hints and "+" are kept.
    @Test func pickingAClipKeepsWhatPickingDoesntChange() async throws {
        let scene = try await makeScene()
        let before = Set(scene.layers.map(ObjectIdentifier.init))
        scene.viewModel.clips.selectClipAtPlayhead()
        scene.show()
        let after = scene.layers.map(ObjectIdentifier.init)
        let kept = after.filter(before.contains).count
        #expect(kept > 0)
        #expect(kept < before.count)
    }
}
