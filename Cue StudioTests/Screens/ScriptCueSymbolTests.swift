//
//  ScriptCueSymbolTests.swift
//  Cue StudioTests
//

import Testing
import UIKit
@testable import Cue_Studio

@Suite("ScriptCueSymbol")
struct ScriptCueSymbolTests {
    @Test func theOwnersCuesHaveTheirSymbols() {
        #expect(ScriptCueSymbol.name(forCue: "pause") == "pause.fill")
        #expect(ScriptCueSymbol.name(forCue: "look at camera") == "eye")
        #expect(ScriptCueSymbol.name(forCue: "demo") == "hand.point.up")
        #expect(ScriptCueSymbol.name(forCue: "smile") == "face.smiling")
        #expect(ScriptCueSymbol.name(forCue: "emphasis") == "exclamationmark")
    }

    /// A Portuguese script keeps its cues in Portuguese whatever the interface's language; case and accents don't matter.
    @Test func aCueIsKnownInAnyOfTheAppsLanguages() {
        #expect(ScriptCueSymbol.name(forCue: "pausa") == "pause.fill")
        #expect(ScriptCueSymbol.name(forCue: "olhe para a câmera") == "eye")
        #expect(ScriptCueSymbol.name(forCue: "Olhe para a camera") == "eye")
        #expect(ScriptCueSymbol.name(forCue: " Pause ") == "pause.fill")
    }

    @Test func aCreatorsOwnCueHasNoSymbol() {
        #expect(ScriptCueSymbol.name(forCue: "laugh") == nil)
        #expect(ScriptCueSymbol.name(forCue: "") == nil)
    }

    @Test func everySymbolExists() {
        for cue in ScriptCue.allCases {
            #expect(UIImage(systemName: ScriptCueSymbol.name(for: cue)) != nil, "\(cue)")
            #expect(ScriptCueSymbol.name(forCue: cue.name) == ScriptCueSymbol.name(for: cue), "\(cue) by its own name")
        }
    }
}
