//
//  SpeechCapabilityCheckerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Dictation, Voice Following and captions listen through the same recognizers, so one answer serves
/// them: supported, model not on the device yet, or not available (and why).
@Suite("SpeechCapabilityChecker")
struct SpeechCapabilityCheckerTests {
    private func support(_ language: CueLanguage, on catalog: FakeSpeechLocaleCatalog) async -> FeatureSupport {
        await SpeechCapabilityChecker(catalog: catalog).support(for: language)
    }

    @Test func aModelOnTheDeviceIsSupported() async {
        let catalog = FakeSpeechLocaleCatalog(transcriber: ["en-US"], dictation: ["en-US"], installed: ["en-US"])
        #expect(await support(.english, on: catalog) == .supported)
    }

    @Test func aModelThatDownloadsOnFirstUseIsNotInstalledYet() async {
        let catalog = FakeSpeechLocaleCatalog(transcriber: ["en-US", "es-ES"], dictation: ["en-US"], installed: ["en-US"])
        #expect(await support(.spanish, on: catalog) == .notInstalled)
    }

    @Test func aLanguageTheRecognizersDoNotOfferIsUnavailableNotReplaced() async {
        let catalog = FakeSpeechLocaleCatalog(transcriber: ["en-US"], dictation: ["en-US"], installed: ["en-US"])
        #expect(await support(.thai, on: catalog) == .unavailable(.languageNotSupported))
        // Brazilian Portuguese is not answered with European Portuguese.
        let european = FakeSpeechLocaleCatalog(dictation: ["pt-PT"], defaults: ["pt-BR": "pt-PT"])
        #expect(await support(.portugueseBrazil, on: european) == .unavailable(.languageNotSupported))
    }

    @Test func aDeviceWithoutRecognitionIsToldApartFromALanguageWithout() async {
        #expect(await support(.english, on: FakeSpeechLocaleCatalog()) == .unavailable(.deviceNotSupported))
        // The simulator lists a model it can't run.
        let simulator = FakeSpeechLocaleCatalog(dictation: ["en-US"], installed: ["en-US"], cannotRun: ["en-US"])
        #expect(await support(.english, on: simulator) == .unavailable(.deviceNotSupported))
    }

    /// `SpeechTranscriber` writes Hindi in Latin letters; Devanagari is the dictation model's.
    @Test func hindiIsAskedForTheModelThatWritesDevanagari() async {
        let catalog = FakeSpeechLocaleCatalog(transcriber: ["hi-IN"], dictation: ["hi-IN"], installed: ["hi-IN"])
        let route = try? await SpeechLocaleResolver(catalog: catalog).resolve(.language(.hindi), scriptText: CueLanguage.hindi.nativeName).get()
        #expect(route?.engine == .dictation)
        #expect(await support(.hindi, on: catalog) == .supported)
    }

    @Test func eachOfTheTwentyLanguagesIsAnswered() async {
        let everything = FakeSpeechLocaleCatalog(
            transcriber: CueLanguage.allCases.map(\.rawValue), dictation: CueLanguage.allCases.map(\.rawValue),
            installed: Set(CueLanguage.allCases.map(\.rawValue))
        )
        for language in CueLanguage.allCases {
            #expect(await support(language, on: everything) == .supported, "\(language.rawValue)")
        }
    }

    @Test func aDownloadThatJustFailedIsNotAskedAgainAtOnce() {
        var cooldown = DownloadCooldown(clock: { 100 })
        let thai = Locale(identifier: "th-TH")
        #expect(!cooldown.isCoolingDown(thai))
        cooldown.failed(thai)
        #expect(cooldown.isCoolingDown(thai))
        #expect(!cooldown.isCoolingDown(Locale(identifier: "hi-IN")))
    }

    @Test func aFailedDownloadIsTriedAgainAfterTheCooldown() {
        final class Clock: @unchecked Sendable { var now: TimeInterval = 100 }
        let clock = Clock()
        var cooldown = DownloadCooldown(clock: { clock.now })
        let thai = Locale(identifier: "th-TH")
        cooldown.failed(thai)
        clock.now += DownloadCooldown.duration - 1
        #expect(cooldown.isCoolingDown(thai))
        clock.now += 2
        #expect(!cooldown.isCoolingDown(thai))
    }
}
