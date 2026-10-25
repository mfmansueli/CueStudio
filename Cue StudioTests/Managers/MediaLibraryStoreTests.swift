//
//  MediaLibraryStoreTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cue_Studio

/// The media library's files: a file comes in once (the same bytes again are the same asset), as a link to bytes Cue already
/// has; a see-through picture is a logo; a video gets its own link to it (no copy), which outlives the asset leaving the
/// library; a file gone or broken is said, not hidden; reopening reads the list back; and a file the list doesn't name (an
/// import stopped halfway, a removed asset past its Undo) goes at a later launch, never one it names or one just written.
@MainActor
@Suite("Media library")
struct MediaLibraryStoreTests {
    private func makeStore() -> MediaLibraryStore {
        let folder = URL.temporaryDirectory.appending(path: "Library-\(UUID().uuidString)", directoryHint: .isDirectory)
        return MediaLibraryStore(repository: LocalMediaLibraryRepository(directory: folder), directory: folder)
    }

    /// A PNG `width`×`height` (solid red, or red on a clear background) brought into the library the way an import is: the
    /// imported copy's own name goes once the library has its link.
    private func add(
        _ store: MediaLibraryStore, width: Int = 64, height: Int = 32, seeThrough: Bool = false, name: String? = nil
    ) async throws -> LibraryAsset {
        let file = try picture(width: width, height: height, seeThrough: seeThrough)
        defer { try? FileManager.default.removeItem(at: file) }
        return try await store.add(fileAt: file, name: name).asset
    }

    /// A PNG `width`×`height`: solid red, or red on a clear background.
    private func picture(width: Int = 64, height: Int = 32, seeThrough: Bool = false) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(seeThrough ? CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2) : CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let url = URL.temporaryDirectory.appending(path: "pic-\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test func aFileComesInOnceAndASeeThroughPictureIsALogo() async throws {
        let store = makeStore()
        defer { store.eraseAll() }
        let photo = try picture()
        let added = try await store.add(fileAt: photo)
        guard case .added(let asset) = added else { Issue.record("Not added"); return }
        #expect(asset.kind == .photo)
        #expect(asset.name == "Photo 1")
        #expect(abs(asset.aspect - 2) < 0.01)
        // The same bytes again: the same asset, no second file.
        #expect(try await store.add(fileAt: photo) == .alreadyThere(asset))
        #expect(store.assets.count == 1)
        let logo = try await store.add(fileAt: try picture(seeThrough: true)).asset
        #expect(logo.kind == .logo)
        #expect(store.assets(in: .logos).map(\.id) == [logo.id])
        #expect(store.assets(in: .photos).map(\.id) == [asset.id])
    }

    @Test func aVideoGetsItsOwnLinkThatOutlivesTheAsset() async throws {
        let store = makeStore()
        defer { store.eraseAll() }
        let asset = try await add(store)
        let media = try store.media(for: asset)
        defer { EditMediaFiles.remove([media.fileName]) }
        #expect(media.fileName != asset.fileName)
        #expect(MediaLibraryFiles.linkCount(of: asset.fileName, in: store.directory) == 2)
        #expect(store.asset(asset.id)?.usedAt != nil)
        // Out of the library, and even its file gone: the video's file is whole.
        store.remove(asset.id)
        try FileManager.default.removeItem(at: store.url(of: asset))
        #expect(LibraryFileReader.picture(at: EditMediaFiles.url(for: media.fileName)) != nil)
    }

    @Test func twoVideosUsingTheSameAssetEachKeepTheirOwn() async throws {
        let store = makeStore()
        defer { store.eraseAll() }
        let asset = try await add(store)
        let first = try store.media(for: asset)
        let second = try store.media(for: asset)
        defer { EditMediaFiles.remove([second.fileName]) }
        #expect(first.fileName != second.fileName)
        #expect(MediaLibraryFiles.linkCount(of: asset.fileName, in: store.directory) == 3)
        // One video goes (its take deleted): the other video and the library are whole.
        EditMediaFiles.remove([first.fileName])
        #expect(MediaLibraryFiles.linkCount(of: asset.fileName, in: store.directory) == 2)
        #expect(LibraryFileReader.picture(at: EditMediaFiles.url(for: second.fileName)) != nil)
        #expect(LibraryFileReader.picture(at: store.url(of: asset)) != nil)
    }

    @Test func aNewLinkToOldBytesCountsAsNew() async throws {
        let old = try picture()
        let monthAgo = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: monthAgo], ofItemAtPath: old.path(percentEncoded: false))
        let folder = URL.temporaryDirectory.appending(path: "Links-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let name = try MediaLibraryFiles.keep(old, in: folder)
        // Its bytes are a month old; the link was made now: no sweep takes it for settled.
        let date = try #require(EditStorageCleaner.modified(in: folder)[name])
        #expect(date > Date.now.addingTimeInterval(-60))
        #expect(LibraryFileSweep.strays(files: [name: date], list: "", launchedAt: .now).isEmpty)
    }

    @Test func aMissingOrBrokenFileIsSaid() async throws {
        let store = makeStore()
        defer { store.eraseAll() }
        let gone = try await add(store)
        let broken = try await add(store, width: 10, height: 10)
        try FileManager.default.removeItem(at: store.url(of: gone))
        try Data("damaged".utf8).write(to: store.url(of: broken))
        await store.checkStatus(of: gone)
        await store.checkStatus(of: broken)
        #expect(store.status(of: gone) == .missing)
        #expect(store.status(of: broken) == .unreadable)
        #expect(Set(store.brokenAssets.map(\.id)) == [gone.id, broken.id])
        #expect(throws: EditMediaImportError.self) { try store.media(for: gone) }
    }

    @Test func namesFavoritesKindsSearchAndReopening() async throws {
        let store = makeStore()
        defer { store.eraseAll() }
        let first = try await add(store, name: "Studio wall")
        let second = try await add(store, width: 20, height: 20, name: "Desk")
        store.rename(second.id, to: "  Desk top  ")
        store.toggleFavorite(first.id)
        store.setKind(second.id, .logo)
        #expect(store.asset(second.id)?.name == "Desk top")
        #expect(store.assets(in: .all).first?.id == first.id)
        #expect(store.assets(in: .favorites).map(\.id) == [first.id])
        #expect(store.assets(in: .all, matching: "desk").map(\.id) == [second.id])
        #expect(store.assets(in: .all, matching: "logo").map(\.id) == [second.id])
        let reopened = MediaLibraryStore(repository: LocalMediaLibraryRepository(directory: store.directory), directory: store.directory)
        reopened.load()
        #expect(reopened.assets.count == 2)
        #expect(reopened.asset(first.id)?.isFavorite == true)
        #expect(reopened.asset(second.id)?.kind == .logo)
    }

    @Test func removingHasUndoAndTheFileGoesAtALaterLaunch() async throws {
        let store = makeStore()
        defer { store.eraseAll() }
        let kept = try await add(store)
        let removed = try await add(store, width: 30, height: 30)
        let gone = try #require(store.remove(removed.id))
        store.restore(gone)
        #expect(store.assets.count == 2)
        store.remove(removed.id)
        // An import stopped halfway: a file the list never named.
        let stray = store.directory.appending(path: "stray.mov")
        try Data("half".utf8).write(to: stray)
        let list = try String(contentsOf: store.directory.appending(path: "library.json"), encoding: .utf8)
        let files = EditStorageCleaner.modified(in: store.directory)
        // Just written: nothing goes yet.
        #expect(LibraryFileSweep.strays(files: files, list: list, launchedAt: .now).isEmpty)
        let later = Date.now.addingTimeInterval(LibraryFileSweep.settleAge + 60)
        #expect(LibraryFileSweep.strays(files: files, list: list, launchedAt: later) == ["stray.mov", removed.fileName])
        #expect(!LibraryFileSweep.strays(files: files, list: list, launchedAt: later).contains(kept.fileName))
    }
}
