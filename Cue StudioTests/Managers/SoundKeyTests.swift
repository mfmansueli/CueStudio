//
//  SoundKeyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Words compared by how they sound, in any writing system: what a recognizer wrote for a name sounds like the name.
@Suite("Sound key")
struct SoundKeyTests {
    @Test func everyWritingSystemIsReadInLatinLetters() {
        #expect(SoundKey.of(["Schlegel"]) == "slegel")
        #expect(SoundKey.of(["普通"]) == SoundKey.of(["普通"]))
        #expect(!SoundKey.of(["अणुओं"]).isEmpty && !SoundKey.of(["المحيط"]).isEmpty && !SoundKey.of(["드래곤"]).isEmpty)
        #expect(SoundKey.of(["2006", "!"]).isEmpty)
    }

    /// Readings on an iPhone: what the recognizer wrote for a name, against the name.
    @Test func whatARecognizerWroteForANameSoundsLikeIt() {
        #expect(SoundKey.likeness(["Jean", "Carlos"], ["Giancarlo"]) >= 0.65)
        #expect(SoundKey.likeness(["yeşile", "gel"], ["ve", "Schlegel"]) >= 0.65)
        #expect(SoundKey.likeness(["Gitley"], ["Gridley"]) >= 0.65)
        #expect(SoundKey.likeness(["普动"], ["普通"]) >= 0.65)
        // Different words don't.
        #expect(SoundKey.likeness(["oi", "gente", "tudo", "bem"], ["Hey", "guys", "welcome", "back"]) < 0.5)
        #expect(SoundKey.likeness(["disse", "que", "ela"], ["Giancarlo"]) < 0.65)
    }
}
