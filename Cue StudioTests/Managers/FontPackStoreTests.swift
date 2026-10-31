//
//  FontPackStoreTests.swift
//  Cue StudioTests
//

import CryptoKit
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The script libraries' files: downloaded once per weight, only when asked, checked against the manifest before they are
/// kept, registered and handed to the renderers, kept out of the backup, registered again at the next launch, and removed
/// for good. A file that fails its check never draws.
@MainActor
@Suite("Font pack store")
struct FontPackStoreTests {
    /// A file of the app (Poppins draws Devanagari) standing in for a library family's.
    private static let file: (data: Data, name: String) = {
        let url = Bundle.main.url(forResource: "Poppins-Bold", withExtension: "ttf")!
        return (try! Data(contentsOf: url), "Poppins-Bold.ttf") // swiftlint:disable:this force_try
    }()

    private static func pack(sha256: String? = nil) -> FontPack {
        let digest = SHA256.hash(data: file.data).map { String(format: "%02x", $0) }.joined()
        return FontPack(
            id: "testpack", family: "Test Pack", script: .devanagari, character: .sans, licence: "OFL", copyright: "Copyright",
            files: [
                FontPack.File(
                    file: file.name, url: URL(string: "https://example.com/\(file.name)")!, sha256: sha256 ?? digest, bytes: file.data.count,
                    postScriptName: "Poppins-Bold", weight: 700
                ),
            ]
        )
    }

    private func store(_ pack: FontPack, source: FakeFontPackSource, registry: FontPackRegistry) -> (FontPackStore, URL) {
        let folder = URL.temporaryDirectory.appending(path: "FontPacks-\(UUID().uuidString)", directoryHint: .isDirectory)
        let manifest = FontPackManifest(source: "test", packs: [pack])
        return (FontPackStore(manifest: manifest, source: source, directory: folder, registry: registry), folder)
    }

    @Test func aFileIsDownloadedCheckedKeptAndDrawn() async throws {
        let pack = Self.pack()
        let source = FakeFontPackSource(files: [Self.file.name: Self.file.data])
        let registry = FontPackRegistry()
        let (store, folder) = store(pack, source: source, registry: registry)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(store.state(of: pack) == .absent)
        let generation = store.generation
        let task = store.request(pack, weight: .bold)
        // Asked again while it downloads: one download.
        store.request(pack, weight: .heavy)
        #expect(await task.value)
        #expect(source.asks == [Self.file.name])
        #expect(store.state(of: pack, weight: .bold) == .ready)
        #expect(store.generation > generation)
        #expect(registry.face(of: pack, weight: .bold)?.postScriptName == "Poppins-Bold")
        let kept = FontPackFiles.url(of: pack, pack.files[0], in: folder)
        #expect(FontPackFiles.exists(kept))
        #expect(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(store.downloaded.map(\.pack.id) == ["testpack"])
        // Here already: not downloaded again.
        #expect(await store.request(pack, weight: .bold).value)
        #expect(source.asks.count == 1)
    }

    @Test func aFileThatFailsItsCheckIsThrownAway() async {
        let pack = Self.pack(sha256: String(repeating: "0", count: 64))
        let registry = FontPackRegistry()
        let (store, folder) = store(pack, source: FakeFontPackSource(files: [Self.file.name: Self.file.data]), registry: registry)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(await store.request(pack, weight: .bold).value == false)
        #expect(store.state(of: pack) == .failed)
        #expect(registry.face(of: pack, weight: .bold) == nil)
        #expect(!FontPackFiles.exists(FontPackFiles.url(of: pack, pack.files[0], in: folder)))
    }

    @Test func aDownloadThatFailsCanBeTriedAgain() async {
        let pack = Self.pack()
        let (store, folder) = store(pack, source: FakeFontPackSource(), registry: FontPackRegistry())
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(await store.request(pack, weight: .bold).value == false)
        #expect(store.state(of: pack) == .failed)
    }

    @Test func keptFilesAreRegisteredAgainAtLaunchWithoutDownloading() async throws {
        let pack = Self.pack()
        let registry = FontPackRegistry()
        let (first, folder) = store(pack, source: FakeFontPackSource(files: [Self.file.name: Self.file.data]), registry: registry)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(await first.request(pack, weight: .bold).value)
        let fresh = FontPackRegistry()
        let source = FakeFontPackSource()
        let next = FontPackStore(manifest: FontPackManifest(source: "test", packs: [pack]), source: source, directory: folder, registry: fresh)
        next.load()
        #expect(source.asks.isEmpty)
        #expect(next.state(of: pack) == .ready)
        #expect(fresh.face(of: pack, weight: .bold) != nil)
    }

    @Test func removingAFamilyDeletesItsFiles() async {
        let pack = Self.pack()
        let registry = FontPackRegistry()
        let (store, folder) = store(pack, source: FakeFontPackSource(files: [Self.file.name: Self.file.data]), registry: registry)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(await store.request(pack, weight: .bold).value)
        store.remove(pack)
        #expect(store.state(of: pack) == .absent)
        #expect(registry.face(of: pack, weight: .bold) == nil)
        #expect(!FontPackFiles.exists(FontPackFiles.url(of: pack, pack.files[0], in: folder)))
        #expect(store.downloaded.isEmpty)
    }

    @Test func anExportWaitsForTheFamiliesItNeedsAtMostSoLong() async {
        let pack = Self.pack()
        let (store, folder) = store(pack, source: FakeFontPackSource(files: [Self.file.name: Self.file.data]), registry: FontPackRegistry())
        defer { try? FileManager.default.removeItem(at: folder) }
        let needs: Set = [FontPackNeed(packID: pack.id, weight: .bold)]
        store.request(needs)
        await store.awaitDownloads(needs, timeout: .seconds(10))
        #expect(store.state(of: pack) == .ready)
        // Nothing on its way: no wait at all.
        let clock = ContinuousClock()
        let waited = await clock.measure { await store.awaitDownloads([FontPackNeed(packID: "other", weight: .bold)], timeout: .seconds(10)) }
        #expect(waited < .seconds(1))
    }
}
