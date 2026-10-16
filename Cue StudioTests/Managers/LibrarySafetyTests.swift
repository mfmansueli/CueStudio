//
//  LibrarySafetyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What's saved survives a damaged entry: one take or one text that can't be read stays out alone (the file as it was is
/// kept aside), and a library that couldn't be read at all is never written over.
@MainActor
@Suite("Library safety")
struct LibrarySafetyTests {
    private struct Thing: Codable, Equatable {
        let name: String
    }

    private enum HolderKeys: String, CodingKey { case things }

    private struct Holder: Decodable {
        let things: [Thing]
        init(from decoder: Decoder) throws {
            things = try decoder.container(keyedBy: HolderKeys.self).decodeLossy([Thing].self, forKey: .things)
        }
    }

    @Test func aDamagedElementStaysOutAlone() throws {
        let json = Data(#"[{"name":"a"},{"nome":"broken"},{"name":"c"},42]"#.utf8)
        let list = try JSONDecoder().decode(LossyList<Thing>.self, from: json)
        #expect(list.elements == [Thing(name: "a"), Thing(name: "c")])
        #expect(list.dropped == 2)
        // Missing, or not a list at all: empty, never a failure.
        #expect(try JSONDecoder().decode(Holder.self, from: Data(#"{}"#.utf8)).things.isEmpty)
        #expect(try JSONDecoder().decode(Holder.self, from: Data(#"{"things":"x"}"#.utf8)).things.isEmpty)
    }

    @Test func aDamagedTakeLeavesTheOthersAndACopyOfTheFile() throws {
        let folder = URL.temporaryDirectory.appending(path: "takes-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LocalTakeRepository(directory: folder)
        let take = TestData.take(scriptID: nil, number: 1)
        try repository.saveTakes([take])
        // A second entry the app can't read (no file name).
        let file = folder.appending(path: "takes.json")
        var entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [Any])
        entries.append(["id": UUID().uuidString])
        try JSONSerialization.data(withJSONObject: entries).write(to: file)
        let loaded = try repository.loadTakes()
        #expect(loaded.map(\.id) == [take.id])
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).filter { $0.hasPrefix("takes-kept-") }
        #expect(kept.count == 1)
    }

    @MainActor
    @Test func aLibraryThatCouldntBeReadIsNeverWrittenOver() {
        let repository = UnreadableTakeRepository()
        let takes = TakeLibraryService(repository: repository)
        takes.load()
        // A new recording while the library couldn't be read: kept in memory, never written over the library on disk.
        _ = try? takes.addTake(fileAt: URL.temporaryDirectory.appending(path: "new.mov"), duration: 5, script: nil, camera: CameraSettings())
        #expect(takes.takes.count == 1)
        #expect(repository.saves == 0)
    }
}

extension LibrarySafetyTests {
    @Test func aDamagedScriptLeavesTheOthersAndACopyOfTheFile() throws {
        let folder = URL.temporaryDirectory.appending(path: "scripts-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LocalScriptRepository(directory: folder)
        let script = TestData.script()
        try repository.save(ScriptLibrarySnapshot(scripts: [script], folders: ["Ideas"]))
        let file = folder.appending(path: "scripts.json")
        var library = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        library["scripts"] = ((library["scripts"] as? [Any]) ?? []) + [["title": 7]]
        try JSONSerialization.data(withJSONObject: library).write(to: file)
        let loaded = try repository.load()
        #expect(loaded.scripts.map(\.id) == [script.id])
        #expect(loaded.folders == ["Ideas"])
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).filter { $0.hasPrefix("scripts-kept-") }
        #expect(kept.count == 1)
    }

    @MainActor
    @Test func aScriptLibraryThatCouldntBeReadIsNeverWrittenOver() {
        let repository = UnreadableScriptRepository()
        let library = ScriptLibraryService(repository: repository)
        library.load()
        _ = library.createFolder(named: "New")
        #expect(repository.saves == 0)
    }
}

extension LibrarySafetyTests {
    @MainActor
    @Test func brandsThatCouldntBeReadAreNeverWrittenOver() {
        let repository = UnreadableBrandRepository()
        let brands = BrandStore(repository: repository)
        brands.load()
        brands.remove(UUID())
        #expect(repository.saves == 0)
    }
}

private final class UnreadableBrandRepository: BrandRepository {
    private(set) var saves = 0
    func load() throws -> [BrandBrief] { throw CocoaError(.fileReadNoPermission) }
    func save(_ brands: [BrandBrief]) throws { saves += 1 }
}

private final class UnreadableScriptRepository: ScriptRepository {
    private(set) var saves = 0
    func load() throws -> ScriptLibrarySnapshot { throw CocoaError(.fileReadNoPermission) }
    func save(_ snapshot: ScriptLibrarySnapshot) throws { saves += 1 }
}

/// A library on disk that can't be read (before the first unlock, or damaged beyond reading): `loadTakes` throws.
private final class UnreadableTakeRepository: TakeRepository {
    private(set) var saves = 0
    func loadTakes() throws -> [Take] { throw CocoaError(.fileReadNoPermission) }
    func saveTakes(_ takes: [Take]) throws { saves += 1 }
    func storeVideo(from temporaryURL: URL) throws -> String { "" }
    func deleteVideo(named fileName: String) throws {}
    func videoURL(named fileName: String) -> URL { URL.temporaryDirectory.appending(path: fileName) }
}
