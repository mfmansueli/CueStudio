//
//  SpeechLocaleReservationTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Which language makes room when the system's five places are taken: one not used since launch, else the one used longest ago,
/// never the one being reserved, whatever order the system lists them in.
@Suite("SpeechLocaleReservation")
struct SpeechLocaleReservationTests {
    /// German was just reserved to compare a take in Portuguese, English, Spanish and German: none of them makes room.
    @Test func aLanguageInUseNeverMakesRoom() {
        let reserved = ["de-DE", "en-US", "es-ES", "fr-FR", "ja-JP"]
        let order = ["de-DE", "pt-BR"]
        #expect(SpeechLocaleReservation.toRelease(from: reserved, making: "pt-BR", usedInOrder: order) == "en-US")
        let later = ["fr-FR", "ja-JP", "de-DE", "pt-BR", "en-US", "es-ES"]
        #expect(SpeechLocaleReservation.toRelease(from: ["de-DE", "en-US", "es-ES", "pt-BR", "zh-CN"], making: "es-ES", usedInOrder: later) == "zh-CN")
    }

    @Test func theLanguageUsedLongestAgoMakesRoom() {
        let order = ["ko-KR", "fr-FR", "de-DE", "en-US", "es-ES", "pt-BR"]
        #expect(SpeechLocaleReservation.toRelease(from: ["de-DE", "en-US", "es-ES", "fr-FR", "ko-KR"], making: "pt-BR", usedInOrder: order) == "ko-KR")
        #expect(SpeechLocaleReservation.toRelease(from: ["pt-BR"], making: "pt-BR", usedInOrder: order) == nil)
    }

    /// Simplified and Traditional Chinese share a model: making room for one never releases the other while another language can.
    @Test func anotherVariantOfTheLanguageIsReleasedLast() {
        let order = ["zh-CN", "hi-IN", "pt-BR", "en-US", "es-ES", "zh-TW"]
        let reserved = ["zh-CN", "es-ES", "pt-BR", "en-US", "hi-IN"]
        #expect(SpeechLocaleReservation.toRelease(from: reserved, making: "zh-TW", usedInOrder: order) == "hi-IN")
        #expect(SpeechLocaleReservation.toRelease(from: ["zh-CN"], making: "zh-TW", usedInOrder: order) == "zh-CN")
    }
}
