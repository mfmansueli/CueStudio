//
//  UITestLeftoversTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A real Debug launch gives back the space UI tests took (`UITestLeftovers.removeAll`): the sample videos, the demo edit's media,
/// the asset folders; never a take, an export, a sound of the cache or an edit's own media.
struct UITestLeftoversTests {
    @Test func aRealLaunchRemovesOnlyWhatUITestsLeft() async throws {
        let root = URL.temporaryDirectory.appending(path: "leftovers-\(UUID().uuidString)", directoryHint: .isDirectory)
        let temporary = root.appending(path: "tmp", directoryHint: .isDirectory)
        let media = root.appending(path: "EditMedia", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = FileManager.default
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        try manager.createDirectory(at: media, withIntermediateDirectories: true)
        try manager.createDirectory(at: temporary.appending(path: "UITestAssets-ABC"), withIntermediateDirectories: true)
        let gone = ["sample-0000-1.mov", "sample-demo-edit.mov", "demo-take-1.mov", "seed-2.png"]
        let stay = ["Cue-1234.mov", "Cue-mix-1.caf", "take-1.mov"]
        for name in gone + stay { try Data([1]).write(to: temporary.appending(path: name)) }
        for name in ["sample-demo-music.caf", "import-photo.jpg"] { try Data([1]).write(to: media.appending(path: name)) }

        await UITestLeftovers.removeAll(temporary: temporary, media: media)

        let leftInTemporary = Set(try manager.contentsOfDirectory(atPath: temporary.path(percentEncoded: false)))
        let leftInMedia = Set(try manager.contentsOfDirectory(atPath: media.path(percentEncoded: false)))
        #expect(leftInTemporary == Set(stay))
        #expect(leftInMedia == ["import-photo.jpg"])
    }

    /// `-uiTestRealTake` plays a hard link of the creator's recording: the link goes, the recording it came from stays whole.
    @Test func theRealTakeLinkGoesAndTheRecordingStays() async throws {
        let root = URL.temporaryDirectory.appending(path: "leftovers-\(UUID().uuidString)", directoryHint: .isDirectory)
        let media = root.appending(path: "EditMedia", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        let recording = root.appending(path: "AB8220F7-09E2-4EF0-9638-271FC60AF798.mov")
        try Data(repeating: 7, count: 1024).write(to: recording)
        let link = root.appending(path: "real-AB8220F7-09E2-4EF0-9638-271FC60AF798.mov")
        try FileManager.default.linkItem(at: recording, to: link)

        await UITestLeftovers.removeAll(temporary: root, media: media)

        #expect(!FileManager.default.fileExists(atPath: link.path(percentEncoded: false)))
        #expect(try Data(contentsOf: recording).count == 1024)
    }
}
