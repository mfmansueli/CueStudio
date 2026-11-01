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
/// script), in its own frame, and opens straight in the editor; a failure says so (a full iPhone only when it is one) and leaves nothing behind.
@MainActor
@Suite("Import video")
struct TakesImportTests {
    private final class FakeImporter: TakeVideoImporting {
        var video: ImportedTakeVideo?
        var error: (any Error)?
        func importVideo(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedTakeVideo {
            if let error { throw error }
            guard let video else { throw EditMediaImportError.unreadable }
            return video
        }
    }

    private func makeViewModel(
        _ importer: FakeImporter, repository: FakeTakeRepository = FakeTakeRepository(takes: [])
    ) -> (TakesViewModel, TakeLibraryService, PresentationService, ToastService) {
        let takes = TakeLibraryService(repository: repository)
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

    private func copy() throws -> URL {
        let copy = URL.temporaryDirectory.appending(path: "import-\(UUID().uuidString).mov")
        try Data("video".utf8).write(to: copy)
        return copy
    }

    /// The iPhone full when the library is written (B13): it says so, and the copy this attempt made goes.
    @Test func aFullIPhoneIsSaidAndTheAttemptsCopyGoes() async throws {
        let copy = try copy()
        let importer = FakeImporter()
        importer.video = ImportedTakeVideo(url: copy, duration: 5, uprightSize: CGSize(width: 1080, height: 1920), frameRate: 30)
        let repository = FakeTakeRepository(takes: [])
        repository.failsToSave = true
        let (viewModel, takes, presentation, toast) = makeViewModel(importer, repository: repository)
        await viewModel.importVideo(PhotosPickerItem(itemIdentifier: "video"))
        #expect(takes.takes.isEmpty && presentation.prompter == nil)
        #expect(toast.message == "Not enough space on this iPhone · Free some and try again")
        #expect(!FileManager.default.fileExists(atPath: copy.path(percentEncoded: false)))
    }

    /// Another failure isn't called a full iPhone, and leaves no copy either.
    @Test func anotherFailureIsNotCalledSpace() async throws {
        let copy = try copy()
        let importer = FakeImporter()
        importer.video = ImportedTakeVideo(url: copy, duration: 5, uprightSize: CGSize(width: 1080, height: 1920), frameRate: 30)
        let repository = FakeTakeRepository(takes: [])
        repository.failsToStore = true
        let (viewModel, _, _, toast) = makeViewModel(importer, repository: repository)
        await viewModel.importVideo(PhotosPickerItem(itemIdentifier: "video"))
        #expect(toast.message == "Can't import this video")
        #expect(!FileManager.default.fileExists(atPath: copy.path(percentEncoded: false)))
    }

    /// Photos' copy stopped by a full iPhone (the system's error, under another): it says so.
    @Test func aCopyStoppedByAFullIPhoneIsSaid() async {
        let importer = FakeImporter()
        importer.error = NSError(
            domain: "NSItemProviderErrorDomain", code: -1, userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))]
        )
        let (viewModel, _, _, toast) = makeViewModel(importer)
        await viewModel.importVideo(PhotosPickerItem(itemIdentifier: "video"))
        #expect(toast.message == "Not enough space on this iPhone · Free some and try again")
    }

    /// A failed import's copy that couldn't be removed then is written down; the launch's sweep removes it whatever its age.
    @Test func aCopyWrittenDownIsSweptAtLaunch() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let folder = URL.temporaryDirectory.appending(path: "media-\(UUID().uuidString)", directoryHint: .isDirectory)
        let media = folder.appending(path: "EditMedia", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("half".utf8).write(to: media.appending(path: "HALF.mov"))
        defaults.defaults.set(["HALF.mov", "GONE.mov"], forKey: DefaultsKey.editMediaDeletionsPending)
        EditStorageCleaner.sweepOrphanedMedia(launchedAt: .now, media: media, support: folder, defaults: defaults.defaults)
        #expect(!FileManager.default.fileExists(atPath: media.appending(path: "HALF.mov").path(percentEncoded: false)))
        #expect(defaults.defaults.stringArray(forKey: DefaultsKey.editMediaDeletionsPending) == nil)
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
