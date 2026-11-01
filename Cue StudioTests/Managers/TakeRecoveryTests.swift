//
//  TakeRecoveryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The recordings a past session left in the temporary folder: the camera's from before this launch come back as takes
/// when they play, go when they can't, wait when they can't be read yet, and one of this launch is never touched.
@MainActor
@Suite("TakeRecovery")
struct TakeRecoveryTests {
    private let launch = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func onlyTheCamerasRecordingsFromBeforeThisLaunchAreLeftovers() {
        let files = [
            "take-B.mov": launch.addingTimeInterval(-60), "take-A.mov": launch.addingTimeInterval(-600),
            "take-now.mov": launch.addingTimeInterval(5), "demo-take-1.mov": launch.addingTimeInterval(-60),
            "Cue-audio-1.m4a": launch.addingTimeInterval(-60), "take-notes.txt": launch.addingTimeInterval(-60),
            "memory-take-2.mov": launch.addingTimeInterval(-60),
        ]
        #expect(TakeRecovery.leftovers(files: files, launchedAt: launch) == ["take-A.mov", "take-B.mov"], "oldest first")
    }

    @Test func aVideoThatPlaysComesBackAndNothingElseDoes() {
        #expect(TakeRecovery.verdict(hasVideo: true, duration: 14) == .recover(duration: 14))
        #expect(TakeRecovery.verdict(hasVideo: false, duration: 14) == .remove)
        #expect(TakeRecovery.verdict(hasVideo: true, duration: 0.2) == .remove, "a tap on Record and nothing more")
        #expect(TakeRecovery.verdict(hasVideo: true, duration: .nan) == .remove)
    }

    @Test func leftoversBecomeTakesAndBrokenOnesGo() async throws {
        let folder = URL.temporaryDirectory.appending(path: "recovery-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let launchedAt = Date().addingTimeInterval(60)
        for name in ["take-good.mov", "take-broken.mov", "take-locked.mov", "take-recording.mov", "Cue-audio-1.m4a"] {
            try Data("frames".utf8).write(to: folder.appending(path: name))
        }
        // One of this launch, maybe still recording.
        let recording = folder.appending(path: "take-recording.mov").path(percentEncoded: false)
        try FileManager.default.setAttributes([.modificationDate: launchedAt.addingTimeInterval(5)], ofItemAtPath: recording)
        let repository = FakeTakeRepository()
        let takes = TakeLibraryService(repository: repository)
        var inspected: [String] = []
        let recovered = await TakeRecovery.recover(into: takes, camera: CameraSettings(), launchedAt: launchedAt, folder: folder) { url in
            inspected.append(url.lastPathComponent)
            switch url.lastPathComponent {
            case "take-good.mov": return .recover(duration: 4)
            case "take-locked.mov": return .leave
            default: return .remove
            }
        }
        #expect(recovered == 1)
        #expect(takes.takes.count == 1)
        #expect(takes.takes.first?.duration == 4)
        #expect(takes.takes.first?.scriptID == nil, "which script it was read from isn't known")
        #expect(repository.storedFiles == ["take-good.mov"])
        #expect(!inspected.contains("take-recording.mov"))
        let left = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? [])
        #expect(left == ["take-good.mov", "take-locked.mov", "take-recording.mov", "Cue-audio-1.m4a"], "only the broken one is gone")
    }

    @Test func aLeftoverTheLibraryCantTakeInStaysForTheNextLaunch() async throws {
        let folder = URL.temporaryDirectory.appending(path: "recovery-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("frames".utf8).write(to: folder.appending(path: "take-good.mov"))
        let repository = FakeTakeRepository()
        repository.failsToStore = true
        let takes = TakeLibraryService(repository: repository)
        let recovered = await TakeRecovery.recover(
            into: takes, camera: CameraSettings(), launchedAt: Date().addingTimeInterval(60), folder: folder
        ) { _ in .recover(duration: 4) }
        #expect(recovered == 0)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "take-good.mov").path(percentEncoded: false)))
    }

    /// A take the library couldn't take in left a note of its script: it comes back under that script, at the version it was read from,
    /// not as a freestyle recording; and the note goes with it. A note of a script deleted since leaves it freestyle.
    @Test func aLeftoverWithANoteComesBackUnderItsScript() async throws {
        let folder = URL.temporaryDirectory.appending(path: "recovery-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var script = TestData.script(title: "Morning habits")
        script.version = 4
        let known = folder.appending(path: "take-known.mov"), gone = folder.appending(path: "take-gone.mov")
        for url in [known, gone] { try Data("frames".utf8).write(to: url) }
        TakeRecoveryNote(scriptID: script.id, scriptVersion: 3).write(for: known)
        TakeRecoveryNote(scriptID: UUID(), scriptVersion: 1).write(for: gone)
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let recovered = await TakeRecovery.recover(
            into: takes, camera: CameraSettings(), launchedAt: Date().addingTimeInterval(60), folder: folder,
            inspect: { _ in .recover(duration: 4) }, script: { $0 == script.id ? script : nil }
        )
        #expect(recovered == 2)
        let underScript = try #require(takes.takes.first { $0.scriptID == script.id })
        #expect(underScript.scriptTitle == "Morning habits" && underScript.scriptVersion == 3)
        #expect(takes.takes.filter(\.isFreestyle).count == 1)
        #expect(TakeRecoveryNote.read(for: known) == nil && TakeRecoveryNote.read(for: gone) == nil)
        // "Delete my Cue data" takes the notes with the recordings.
        TakeRecoveryNote(scriptID: script.id, scriptVersion: 3).write(for: known)
        TakeRecovery.removeLeftovers(folder: folder)
        #expect(TakeRecoveryNote.read(for: known) == nil)
    }

    @Test func aRealMovieIsMeasuredAndAFileThatIsntOneIsRemoved() async throws {
        let movie = try await TestClip.make(seconds: 1)
        defer { try? FileManager.default.removeItem(at: movie) }
        guard case .recover(let duration) = await TakeRecovery.verdict(for: movie) else {
            Issue.record("a playable movie should come back")
            return
        }
        #expect(abs(duration - 1) < 0.2)
        let junk = URL.temporaryDirectory.appending(path: "junk-\(UUID().uuidString).mov")
        try Data("not a movie".utf8).write(to: junk)
        defer { try? FileManager.default.removeItem(at: junk) }
        #expect(await TakeRecovery.verdict(for: junk) == .remove)
        let missing = URL.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).mov")
        #expect(await TakeRecovery.verdict(for: missing) == .leave, "what can't be opened is never removed")
    }
}
