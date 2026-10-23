//
//  ReadingVersionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The versions saved edits are read with, frozen: a change here changes how takes already edited look or sound. A save
/// without the number reads as the first version (the look's only when the dials were used); a number newer than this version
/// of Cue knows is read as it can, and Auto's is left out rather than drawn wrong.
@Suite("Reading versions")
struct ReadingVersionTests {
    @Test func theTableIsFrozen() {
        #expect(ReadingVersion.look.current == 2)
        #expect(ReadingVersion.audio.current == 3)
        #expect(ReadingVersion.captionStyle.current == 2)
        #expect(ReadingVersion.captionTranscript.current == 2)
        #expect(ReadingVersion.autoCorrection.current == 1)
        #expect(ReadingVersion.allCases.allSatisfy { $0.first == 1 })
        // Each type's own constant is the table's.
        #expect(LookSettings.currentVersion == ReadingVersion.look.current)
        #expect(VoiceProcessing.currentVersion == ReadingVersion.audio.current)
        #expect(CaptionStyleSpec.currentVersion == ReadingVersion.captionStyle.current)
        #expect(CaptionTranscript.currentVersion == ReadingVersion.captionTranscript.current)
        #expect(AutoCorrection.currentVersion == ReadingVersion.autoCorrection.current)
    }

    @Test func aSaveWithoutTheNumberReadsAsTheFirst() {
        for reading in ReadingVersion.allCases {
            #expect(reading.read(nil) == 1)
            #expect(reading.read(2) == 2)
        }
        #expect(ReadingVersion.look.read(nil, usedOldNumbers: false) == 2)
        #expect(!ReadingVersion.captionTranscript.isCurrent(nil))
        #expect(ReadingVersion.captionTranscript.isCurrent(2))
        #expect(ReadingVersion.captionTranscript.isCurrent(3))
        #expect(CaptionSettings(theme: .pop).styleVersion == 2)
    }

    @Test func autoFromANewerVersionIsLeftOutOfThePictureButKept() throws {
        var newer = AutoCorrection()
        newer.version = ReadingVersion.autoCorrection.current + 1
        newer.vibrance = 0.4
        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        edit.autoCorrection = newer
        #expect(LookSettings(edit).auto == nil)
        // A clip's own: the clip has no Auto, never the take's in its place.
        var known = AutoCorrection()
        known.vibrance = 0.2
        edit.autoCorrection = known
        #expect(LookSettings(edit).auto == known)
        var clipLook = ClipLook()
        clipLook.auto = newer
        #expect(LookSettings(edit).overridden(by: clipLook).auto == nil)
        // Saved and read back, the edit still holds it as it was.
        let read = try JSONDecoder.library.decode(TakeEdit.self, from: JSONEncoder.library.encode(edit))
        #expect(read.autoCorrection == known)
    }
}
