//
//  TakesImportTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import PhotosUI
import SwiftUI
import Testing
@testable import Cue_Studio

/// "Import video" in Takes: a video from Photos becomes a video of its own, marked imported (no take number, no retake, no
/// script), in its own frame, and opens straight in the editor; a failure says so and leaves nothing behind.
@MainActor
@Suite("Import video")
struct TakesImportTests {
    private final class FakeImporter: TakeVideoImporting {
        var video: ImportedTakeVideo?
        func importVideo(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedTakeVideo {
            guard let video else { throw EditMediaImportError.unreadable }
            return video
        }
    }

    private func makeViewModel(_ importer: FakeImporter) -> (TakesViewModel, TakeLibraryService, PresentationService, ToastService) {
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: []))
        takes.load()
        let presentation = PresentationService()
        let toast = ToastService()
        let viewModel = TakesViewModel(
            takes: takes, library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), drafts: FakeDraftStore(),
            presentation: presentation, toast: toast, importer: importer
        )
        return (viewModel, takes, presentation, toast)
    }

    @Test func anImportedVideoIsAVideoOfItsOwnAndOpensInTheEditor() async throws {
        let importer = FakeImporter()
        importer.video = ImportedTakeVideo(
            url: URL.temporaryDirectory.appending(path: "imported.mov"), duration: 42, uprightSize: CGSize(width: 1920, height: 1080), frameRate: 29.97
        )
        let (viewModel, takes, presentation, _) = makeViewModel(importer)
        await viewModel.importVideo(PhotosPickerItem(itemIdentifier: "video"))
        let take = try #require(takes.takes.first)
        #expect(take.isImported)
        #expect(take.isFreestyle)
        #expect(take.label == "Imported")
        #expect(take.aspect == .landscape && take.resolution == .hd1080 && take.frameRate == .fps30)
        #expect(take.duration == 42)
        #expect(viewModel.allVideos.first?.title == "Imported video")
        #expect(presentation.prompter?.reviewTakeID == take.id)
        #expect(presentation.prompter?.reviewAction == .edit)
    }

    @Test func aVideoThatCantBeReadIsSaidAndAddsNothing() async {
        let (viewModel, takes, presentation, toast) = makeViewModel(FakeImporter())
        await viewModel.importVideo(PhotosPickerItem(itemIdentifier: "broken"))
        #expect(takes.takes.isEmpty)
        #expect(presentation.prompter == nil)
        #expect(toast.message == "Can't import this video")
    }

    @Test func takesRecordedBeforeReadAsRecorded() throws {
        let take = TestData.take(scriptID: UUID(), number: 2)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(take)) as? [String: Any])
        json["origin"] = nil
        let read = try JSONDecoder().decode(Take.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!read.isImported)
        #expect(read.label == "Take 2")
    }
}
