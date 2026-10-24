//
//  DictationTimingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The transcriber's words keep their spelling and take dictation's times: the same word by its time, a word heard
/// differently by what dictation heard in its place, a word only the transcriber heard inside its neighbours.
@Suite("DictationTiming")
struct DictationTimingTests {
    private func words(_ heard: [(String, Double, Double)]) -> [TimedWord] {
        heard.map { TimedWord(text: $0.0, start: $0.1, end: $0.2) }
    }

    @Test func theSameWordsTakeDictationsTimes() {
        // human-pt-BR-2 as an iPhone 15 Pro heard it: the transcriber starts "controle" 0.27 s after the voice.
        let transcribed = words([("o", 2.64, 2.94), ("controle", 2.94, 3.12), ("do", 3.12, 3.42), ("carro", 3.42, 3.54)])
        let dictated = words([("o", 2.64, 2.67), ("controle", 2.67, 3.12), ("do", 3.12, 3.24), ("carro", 3.24, 3.57)])
        #expect(DictationTiming.retimed(transcribed, by: dictated) == dictated)
    }

    @Test func theTranscribersSpellingStays() {
        // human-pt-BR-1: dictation wrote "forrar" and no period; the words stay the transcriber's.
        let transcribed = words([("para", 10.26, 10.56), ("honrar", 10.56, 11.28), ("faraós", 11.28, 12.00), ("mortos.", 12.00, 12.90)])
        let dictated = words([("para", 10.23, 10.53), ("forrar", 10.53, 11.28), ("faraós", 11.28, 11.91), ("mortos", 11.91, 12.66)])
        let retimed = DictationTiming.retimed(transcribed, by: dictated)
        #expect(retimed.map(\.text) == ["para", "honrar", "faraós", "mortos."])
        #expect(retimed.map(\.start) == [10.23, 10.53, 11.28, 11.91] && retimed.map(\.end) == [10.53, 11.28, 11.91, 12.66])
    }

    @Test func wordsHeardDifferentlyShareWhatDictationHeardInTheirPlace() {
        // human-pt-BR-2: "Carlos disse que ela" for dictation's "Carlos Ezequiel ela".
        let transcribed = words([("Carlos", 1.26, 1.50), ("disse", 1.50, 1.92), ("que", 1.92, 2.16), ("ela", 2.16, 2.28)])
        let dictated = words([("Carlos", 1.11, 1.53), ("Ezequiel", 1.53, 1.98), ("ela", 1.98, 2.22)])
        let retimed = DictationTiming.retimed(transcribed, by: dictated)
        #expect(retimed[1].start == 1.53 && retimed[1].end == 1.98 && retimed[2].start == 1.53 && retimed[2].end == 1.98)
        #expect(retimed[1].isEstimated && retimed[2].isEstimated && !retimed[3].isEstimated)
        #expect(retimed.map(\.text) == ["Carlos", "disse", "que", "ela"])
    }

    @Test func aWordOnlyTheTranscriberHeardStaysBetweenItsNeighbours() {
        let transcribed = words([("Cristo", 4.86, 5.22), ("a", 5.22, 5.82), ("Grande", 5.82, 6.00)])
        let dictated = words([("Cristo", 4.65, 5.22), ("Grande", 5.58, 5.97)])
        let retimed = DictationTiming.retimed(transcribed, by: dictated)
        #expect(retimed[1].start == 5.22 && retimed[1].end == 5.58 && !retimed[1].isEstimated)
        let touching = words([("Cristo", 4.65, 5.22), ("Grande", 5.22, 5.97)])
        let squeezed = DictationTiming.retimed(transcribed, by: touching)
        #expect(squeezed[1].start >= squeezed[0].start && squeezed[1].start <= squeezed[2].start && squeezed[1].isEstimated)
    }

    @Test func aWordFarInTimeIsntTakenForTheSame() {
        let transcribed = words([("a", 1.0, 1.2), ("casa", 1.2, 1.6)])
        let dictated = words([("casa", 1.15, 1.6), ("a", 2.4, 2.5)])
        let retimed = DictationTiming.retimed(transcribed, by: dictated)
        // "a" 1.4 s away is another "a": the first stays the transcriber's, before "casa".
        #expect(retimed[0].start == 1.0 && retimed[0].end <= retimed[1].start && retimed[1].start == 1.15)
        #expect(DictationTiming.retimed(transcribed, by: []) == transcribed)
    }
}
