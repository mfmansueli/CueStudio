//
//  LibrarySafetyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What's saved survives a damaged entry: one take or one text that can't be read stays out alone (the file as it was is
/// kept aside); a library that couldn't be read at all is never written over, and is read again once it can be, keeping what
/// was made meanwhile; a file that is no longer a library is kept aside and a new one starts.
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

/// Cue woke in the background while the iPhone was locked: the libraries couldn't be read, and are once it is unlocked.
extension LibrarySafetyTests {
    @MainActor
    @Test func aTakeRecordedWhileTheLibraryWasLockedIsKeptWithTheOthersOnceItCanBeRead() throws {
        let old = TestData.take(scriptID: nil, number: 1)
        let repository = LockedTakeRepository(saved: [old])
        let takes = TakeLibraryService(repository: repository)
        takes.load()
        let new = try takes.addTake(fileAt: URL.temporaryDirectory.appending(path: "new.mov"), duration: 5, script: nil, camera: CameraSettings())
        #expect(repository.saves == 0, "never written over the library it couldn't read")

        repository.isLocked = false
        takes.reloadIfUnread()
        #expect(Set(takes.takes.map(\.id)) == [old.id, new.id], "the creator sees both")
        takes.markExported(new.id)
        #expect(Set(repository.saved.map(\.id)) == [old.id, new.id], "and both are saved")
    }

    @MainActor
    @Test func aChangeAfterTheUnlockSavesWhatWasMadeWhileLocked() throws {
        let repository = LockedTakeRepository(saved: [TestData.take(scriptID: nil, number: 1)])
        let takes = TakeLibraryService(repository: repository)
        takes.load()
        let new = try takes.addTake(fileAt: URL.temporaryDirectory.appending(path: "new.mov"), duration: 5, script: nil, camera: CameraSettings())
        // No return to the app in between: the next save reads the library first.
        repository.isLocked = false
        takes.setBest(new.id, isBest: true)
        #expect(repository.saved.count == 2)
        #expect(repository.saved.first { $0.id == new.id }?.isBest == true)
    }

    @MainActor
    @Test func aScriptWrittenWhileTheLibraryWasLockedIsKeptWithTheOthers() {
        let old = TestData.script(title: "On disk")
        let repository = LockedScriptRepository(saved: ScriptLibrarySnapshot(scripts: [old], folders: ["Ideas"]))
        let library = ScriptLibraryService(repository: repository)
        library.load()
        let new = library.create(title: "Written while locked", text: "Hook.", platform: .reels)
        _ = library.createFolder(named: "New")
        #expect(repository.saves == 0)

        repository.isLocked = false
        library.reloadIfUnread()
        #expect(Set(library.scripts.map(\.id)) == [old.id, new.id])
        #expect(library.folders == ["Ideas", "New"])
        library.update(new.id) { $0.text = "Hook, edited." }
        #expect(Set(repository.saved.scripts.map(\.id)) == [old.id, new.id])
        #expect(repository.saved.folders == ["Ideas", "New"])
    }

    @Test func aScriptsFileThatIsNoLongerALibraryIsKeptAsideAndANewOneStarts() throws {
        let folder = URL.temporaryDirectory.appending(path: "scripts-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("{\"scripts\": [".utf8).write(to: folder.appending(path: "scripts.json"))
        let repository = LocalScriptRepository(directory: folder)
        #expect(try repository.load().scripts.isEmpty)
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).filter { $0.hasPrefix("scripts-kept-") }
        #expect(kept.count == 1)
        // And what comes next is saved.
        let script = TestData.script()
        try repository.save(ScriptLibrarySnapshot(scripts: [script]))
        #expect(try repository.load().scripts.map(\.id) == [script.id])
    }

    @Test func aTakesFileThatIsNoLongerAListIsKeptAsideAndANewOneStarts() throws {
        let folder = URL.temporaryDirectory.appending(path: "takes-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("[{\"id\":".utf8).write(to: folder.appending(path: "takes.json"))
        let repository = LocalTakeRepository(directory: folder)
        #expect(try repository.loadTakes().isEmpty)
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).filter { $0.hasPrefix("takes-kept-") }
        #expect(kept.count == 1)
    }
}

/// Takes on disk that can be read only while `isLocked` is false.
private final class LockedTakeRepository: TakeRepository {
    var isLocked = true
    private(set) var saved: [Take]
    private(set) var saves = 0
    init(saved: [Take]) { self.saved = saved }
    func loadTakes() throws -> [Take] {
        if isLocked { throw CocoaError(.fileReadNoPermission) }
        return saved
    }
    func saveTakes(_ takes: [Take]) throws {
        saves += 1
        saved = takes
    }
    func storeVideo(from temporaryURL: URL) throws -> String { "new.mov" }
    func deleteVideo(named fileName: String) throws {}
    func videoURL(named fileName: String) -> URL { URL.temporaryDirectory.appending(path: fileName) }
}

/// Scripts on disk that can be read only while `isLocked` is false.
private final class LockedScriptRepository: ScriptRepository {
    var isLocked = true
    private(set) var saved: ScriptLibrarySnapshot
    private(set) var saves = 0
    init(saved: ScriptLibrarySnapshot) { self.saved = saved }
    func load() throws -> ScriptLibrarySnapshot {
        if isLocked { throw CocoaError(.fileReadNoPermission) }
        return saved
    }
    func save(_ snapshot: ScriptLibrarySnapshot) throws {
        saves += 1
        saved = snapshot
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
