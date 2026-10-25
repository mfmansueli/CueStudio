//
//  QuickEditLogoLimitTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cue_Studio

/// A still logo stays out of the three photos and videos that can show at once (the owner's call, 25/10): three videos fit with
/// it whether it came first or last, and adding, duplicating, moving, stretching, lengthening and replacing all keep the three
/// for everything else; a video marked as a logo still counts, and so does a logo replaced by a video.
@MainActor
@Suite("A still logo and the three at a time")
struct QuickEditLogoLimitTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
        let library: MediaLibraryStore
    }

    /// A 64 s take, with a library to take the logo from.
    private func makeScenario() async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let root = URL.temporaryDirectory.appending(path: "LogoLimit-\(UUID().uuidString)", directoryHint: .isDirectory)
        let media = MediaLibraryStore(
            repository: LocalMediaLibraryRepository(directory: root.appending(path: "Library")), directory: root.appending(path: "Library")
        )
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player, mediaImporter: FakeMediaImporter(),
            recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), mediaLibrary: media
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast, library: media)
    }

    /// A see-through PNG logo, from the library.
    private func logo(_ scenario: Scenario) async throws -> LibraryAsset {
        let context = try #require(CGContext(
            data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.9, green: 0.15, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        let url = URL.temporaryDirectory.appending(path: "logo-\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        let asset = try await scenario.library.add(fileAt: url, name: "Acme logo").asset
        #expect(asset.kind == .logo)
        return asset
    }

    private func video(_ seconds: TimeInterval) -> MediaPick {
        MediaPick(ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 16.0 / 9, duration: seconds, hasSound: false))
    }

    private func photo() -> MediaPick {
        MediaPick(ImportedMedia(kind: .photo, fileName: "p-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
    }

    /// Three 8 s videos in windows, from 10 s.
    private func threeVideos(_ scenario: Scenario) async {
        for _ in 0..<3 {
            scenario.player.seek(to: 10)
            await scenario.viewModel.overlays.add([video(8)], as: .window)
        }
    }

    private func logoMedia(_ viewModel: QuickEditViewModel) -> MediaOverlay? {
        viewModel.edit.media.first { $0.isLogo == true }
    }

    private func bar(_ viewModel: QuickEditViewModel, _ id: UUID) -> LayerBar? {
        viewModel.mediaBars.first { $0.id == id }
    }

    // MARK: - Adding

    @Test func threeVideosFitWithALogoPutOnFirst() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.brand.insertLogo(try await logo(scenario))
        #expect(logoMedia(viewModel)?.isStaticLogo == true)
        await threeVideos(scenario)
        #expect(viewModel.edit.media.count == 4)
        // A fourth video there is still too many: the logo is the only one left out of the three.
        scenario.player.seek(to: 12)
        #expect(viewModel.overlays.insertionRoomIsShort(for: .window))
        await viewModel.overlays.add([video(4)], as: .window)
        #expect(viewModel.edit.media.count == 4)
        #expect(scenario.toast.message == "3 photos or videos already show then · up to 3 at a time" && scenario.toast.kind == .problem)
    }

    @Test func aLogoPutOnLastFitsOverThreeVideosAndGoesWithOneUndo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await threeVideos(scenario)
        let steps = viewModel.document.history.past.count
        viewModel.brand.insertLogo(try await logo(scenario))
        #expect(viewModel.edit.media.count == 4 && logoMedia(viewModel) != nil)
        #expect(viewModel.document.history.past.count == steps + 1)
        // Over the whole video, the three under it untouched.
        let logoID = try #require(logoMedia(viewModel)?.id)
        let logoSpan = try #require(bar(viewModel, logoID)?.span)
        #expect(logoSpan.start < 0.01 && abs(logoSpan.end - viewModel.edit.editedDuration) < 0.01)
        viewModel.undo()
        #expect(viewModel.edit.media.count == 3 && logoMedia(viewModel) == nil)
        viewModel.redo()
        #expect(viewModel.edit.media.count == 4 && logoMedia(viewModel) != nil)
    }

    @Test func aVideoMarkedAsALogoStillCounts() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        for _ in 0..<2 {
            scenario.player.seek(to: 10)
            await viewModel.overlays.add([video(8)], as: .window)
        }
        // A third video, marked as a logo (an old edit, or one written by hand): it isn't a still picture.
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(8)], as: .window)
        let marked = try #require(viewModel.edit.media.last?.id)
        viewModel.changeEdit { edit in
            if let index = edit.media.firstIndex(where: { $0.id == marked }) { edit.media[index].isLogo = true }
        }
        #expect(viewModel.edit.media.contains { $0.isLogo == true && !$0.isStaticLogo })
        scenario.player.seek(to: 12)
        await viewModel.overlays.add([video(4)], as: .window)
        #expect(viewModel.edit.media.count == 3)
        #expect(scenario.toast.kind == .problem)
    }

    // MARK: - Duplicating, moving, stretching, lengthening, replacing

    @Test func duplicatingKeepsTheThreeAndALogosCopyIsALogo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.brand.insertLogo(try await logo(scenario))
        await threeVideos(scenario)
        let first = try #require(viewModel.edit.media.first { $0.isLogo != true })
        viewModel.overlays.duplicateMedia(first.id)
        #expect(viewModel.edit.media.count == 4)
        #expect(scenario.toast.message == "Max 3 photos or videos")
        // The logo's copy is still a still logo: it goes in.
        viewModel.overlays.duplicateMedia(try #require(logoMedia(viewModel)).id)
        #expect(viewModel.edit.media.count == 5 && viewModel.edit.media.filter(\.isStaticLogo).count == 2)
    }

    @Test func movingAndStretchingCountTheOthersButTheLogo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.brand.insertLogo(try await logo(scenario))
        for _ in 0..<2 {
            scenario.player.seek(to: 10)
            await viewModel.overlays.add([video(8)], as: .window)
        }
        // A photo later on: with the logo and two videos at 10–18, it can move there (the logo leaves the third place free).
        scenario.player.seek(to: 30)
        await viewModel.overlays.add([photo()], as: .window)
        let photoID = try #require(viewModel.edit.media.last?.id)
        viewModel.moveBar(try #require(bar(viewModel, photoID)), toStart: 12)
        #expect(abs((bar(viewModel, photoID)?.span.start ?? 0) - 12) < 0.01)
        // A fourth over the same moment can't: moved or stretched there, it stays where it was.
        scenario.player.seek(to: 40)
        await viewModel.overlays.add([photo()], as: .window)
        let fourth = try #require(viewModel.edit.media.last?.id)
        let before = try #require(bar(viewModel, fourth)?.span)
        viewModel.moveBar(try #require(bar(viewModel, fourth)), toStart: 12)
        #expect(bar(viewModel, fourth)?.span == before)
        viewModel.resizeBar(try #require(bar(viewModel, fourth)), edge: .start, to: 14)
        #expect(bar(viewModel, fourth)?.span == before)
    }

    @Test func lengtheningInThePanelKeepsTheThree() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.brand.insertLogo(try await logo(scenario))
        await threeVideos(scenario)
        // A photo just before them: 3 s from 6 s.
        scenario.player.seek(to: 6)
        await viewModel.overlays.add([photo()], as: .window)
        let photoID = try #require(viewModel.edit.media.last?.id)
        let before = try #require(bar(viewModel, photoID)?.span)
        // Longer would run into the three videos: it stays, and says why.
        viewModel.overlays.setMediaLength(photoID, 6)
        #expect(bar(viewModel, photoID)?.span == before)
        #expect(scenario.toast.message == "3 photos or videos already show then · up to 3 at a time")
        // Longer up to them is fine, and shorter always is.
        viewModel.overlays.setMediaLength(photoID, 3.5)
        #expect(abs((bar(viewModel, photoID)?.span.duration ?? 0) - 3.5) < 0.01)
        viewModel.overlays.setMediaLength(photoID, 2)
        #expect(abs((bar(viewModel, photoID)?.span.duration ?? 0) - 2) < 0.01)
    }

    @Test func aLogoReplacedByAVideoCountsAgain() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.brand.insertLogo(try await logo(scenario))
        await threeVideos(scenario)
        let logoID = try #require(logoMedia(viewModel)).id
        viewModel.overlays.replaceMedia(logoID, with: video(60))
        #expect(viewModel.edit.media.first { $0.id == logoID }?.isStaticLogo == true)
        #expect(scenario.toast.message == "3 photos or videos already show then · up to 3 at a time")
        // Another picture in its place stays a still logo.
        viewModel.overlays.replaceMedia(logoID, with: photo())
        #expect(viewModel.edit.media.first { $0.id == logoID }?.isStaticLogo == true)
        #expect(viewModel.edit.media.count == 4)
    }
}
