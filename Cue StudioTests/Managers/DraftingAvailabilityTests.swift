//
//  DraftingAvailabilityTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Apple Intelligence can't draft is told before anything is sent, each reason apart: Cue's switch, the iPhone, the iOS switch, a
/// language the model doesn't write, a model still getting ready.
@MainActor
@Suite("Drafting availability")
struct DraftingAvailabilityTests {
    private let available = AIAvailability(onDevice: true, privateCloud: true, reason: nil)

    @Test func eachFailureIsItsOwnCause() {
        let cases: [(AIPlanFailure, DraftingAvailability.Cause)] = [
            (.deviceNotSupported, .deviceNotSupported),
            (.turnedOff, .turnedOff),
            (.modelPreparing, .modelPreparing),
            (.unsupportedLanguage(Locale.Language(identifier: "th")), .languageNotSupported(.thai)),
        ]
        for (failure, cause) in cases {
            #expect(DraftingAvailability(isEnabled: true, failure: failure, availability: available) == .unavailable(cause))
        }
    }

    @Test func cuesOwnSwitchComesFirstWhateverTheIPhoneSays() {
        let off = DraftingAvailability(isEnabled: false, failure: .unsupportedLanguage(Locale.Language(identifier: "th")), availability: available)
        #expect(off == .unavailable(.turnedOffInCue))
        #expect(off.reason == AIAvailability.turnedOffReason)
    }

    @Test func aWriterThatOnlySaysItCantKeepsItsWords() {
        let none = DraftingAvailability(isEnabled: true, failure: nil, availability: .unavailable)
        #expect(none == .unavailable(.unavailable(reason: AIAvailability.unavailable.reason ?? "")))
        #expect(DraftingAvailability(isEnabled: true, failure: nil, availability: available) == .available)
    }

    @Test func theReasonsAreTheOnesCueAlreadySays() {
        #expect(DraftingAvailability.Cause.deviceNotSupported.reason == AIModelStatus.deviceNotEligible.reason)
        #expect(DraftingAvailability.Cause.turnedOff.reason == AIModelStatus.turnedOff.reason)
        #expect(DraftingAvailability.Cause.modelPreparing.reason == AIModelStatus.preparing.reason)
        #expect(DraftingAvailability.Cause.languageNotSupported(.thai).reason.contains(CueLanguage.thai.localizedName))
        #expect(DraftingAvailability.Cause.languageNotSupported(nil).reason == ScriptAIError.unsupportedLanguage.localizedDescription)
    }

    /// The note offers the ways that need no Apple Intelligence; a model getting ready only asks for a few minutes.
    @Test func theNoteAddsTheWaysThatRemainExceptWhileTheModelGetsReady() {
        let language = DraftingAvailability.unavailable(.languageNotSupported(.thai))
        #expect(language.note?.hasPrefix(language.reason ?? "-") == true)
        #expect(language.note != language.reason)
        let preparing = DraftingAvailability.unavailable(.modelPreparing)
        #expect(preparing.note == preparing.reason)
        #expect(DraftingAvailability.available.note == nil)
    }

    // MARK: - From a writer

    @Test func aWriterAnswersForTheLanguagesAskedOnly() {
        let writer = FakeScriptWriter()
        writer.languagesNotWritten = ["th"]
        #expect(writer.drafting(in: CueLanguage.thai) == .unavailable(.languageNotSupported(.thai)))
        #expect(writer.drafting(in: CueLanguage.english).isAvailable)
        // Auto-detect asks nothing about a language: it isn't known yet.
        #expect(writer.drafting(in: nil as CueLanguage?).isAvailable)
        writer.isEnabled = false
        #expect(writer.drafting(in: CueLanguage.english) == .unavailable(.turnedOffInCue))
    }

    /// Waiting won't help a language the model doesn't write: the real planner says the language, not "getting ready".
    @Test func aModelGettingReadyIsNotBlamedForALanguageItWontWrite() {
        let writer = ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities(device: .preparing))
        #expect(writer.drafting(in: CueLanguage.thai) == .unavailable(.languageNotSupported(.thai)))
        #expect(writer.drafting(in: CueLanguage.english) == .unavailable(.modelPreparing))
        #expect(writer.drafting(in: [Locale.Language]()) == .unavailable(.modelPreparing))
    }

    @Test func theIPhoneAndTheIOSSwitchAreToldWhateverTheLanguage() {
        let ineligible = ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities(device: .deviceNotEligible))
        #expect(ineligible.drafting(in: CueLanguage.thai) == .unavailable(.deviceNotSupported))
        let off = ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities(device: .turnedOff))
        #expect(off.drafting(in: CueLanguage.english) == .unavailable(.turnedOff))
    }

    /// Only a language the model doesn't write gets a line in the Script Language menu: without Apple Intelligence every one would.
    @Test func theScriptLanguageMenuMarksOnlyALanguageTheModelDoesntWrite() {
        #expect(LanguageEntryRow.draftingNote(.unavailable(.languageNotSupported)) != nil)
        #expect(LanguageEntryRow.draftingNote(.unavailable(.deviceNotSupported)) == nil)
        #expect(LanguageEntryRow.draftingNote(.unavailable(.turnedOff)) == nil)
        #expect(LanguageEntryRow.draftingNote(.supported) == nil)
        #expect(LanguageEntryRow.draftingNote(.notInstalled) == nil)
        #expect(LanguageEntryRow.draftingNote(nil) == nil)
    }
}
