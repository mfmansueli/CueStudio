//
//  UltraTitleAccentsTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// A title the model wrote without its script's accents gets them back, and nothing else in it changes.
@Suite("Ultra AI title accents")
struct UltraTitleAccentsTests {
    @Test func theScriptsAccentsComeBack() {
        let script = "Trocar o celular por uma câmera pode atrasar seus vídeos. A câmera pede ajuste."
        #expect(UltraTitleAccents.restored("Celular ou camera para gravar videos", from: script) == "Celular ou câmera para gravar vídeos")
        #expect(UltraTitleAccents.restored("Como mudei minhas manhas", from: "Minhas manhãs ficaram calmas.") == "Como mudei minhas manhãs")
    }

    @Test func capitalsAreKept() {
        let script = "Uma câmera nova não resolve."
        #expect(UltraTitleAccents.restored("Camera nova", from: script) == "Câmera nova")
        #expect(UltraTitleAccents.restored("CAMERA NOVA", from: script) == "CÂMERA NOVA")
    }

    @Test func aWordTheScriptAlsoWritesPlainIsLeftAlone() {
        let script = "Isso é simples e rápido."
        #expect(UltraTitleAccents.restored("Simples e rapido", from: script) == "Simples e rápido")
    }

    @Test func aTitleWithItsAccentsOrWordsTheScriptDoesntHaveIsUnchanged() {
        #expect(UltraTitleAccents.restored("Câmera ou celular", from: "A camera e o celular.") == "Câmera ou celular")
        #expect(UltraTitleAccents.restored("Why rest days matter", from: "Rest days make you stronger.") == "Why rest days matter")
    }
}
