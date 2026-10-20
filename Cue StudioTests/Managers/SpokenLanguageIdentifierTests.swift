//
//  SpokenLanguageIdentifierTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// Which likely language a take is spoken in: the one its recognizer understood best (the scores are the ones measured on an iPhone
/// 15 Pro, `TranscriberLanguageListener`), the first keeping a near tie, and nothing decided without speech or the first's score.
@Suite("SpokenLanguageIdentifier")
struct SpokenLanguageIdentifierTests {
    private final class BundleToken {}

    private func score(_ confidence: Double, _ words: Int = 25) -> SpokenLanguageScore {
        SpokenLanguageScore(confidence: confidence, words: words)
    }

    /// An English recording on an iPhone in Portuguese.
    @Test func theLanguageUnderstoodBestWins() {
        let scores = [CueLanguage.portugueseBrazil: score(0.83), .spanish: score(0.95), .english: score(0.98)]
        #expect(SpokenLanguageIdentifier.pick(scores, first: .portugueseBrazil) == .english)
        // A Portuguese take: English and Spanish understood it far less.
        let take = [CueLanguage.portugueseBrazil: score(0.96), .english: score(0.16), .spanish: score(0.64)]
        #expect(SpokenLanguageIdentifier.pick(take, first: .english) == .portugueseBrazil)
    }

    /// French on an iPhone without the French model: Spanish understood it best, but not well enough to replace the first.
    @Test func aLanguageUnderstoodPoorlyNeverReplacesTheFirst() {
        let scores = [CueLanguage.portugueseBrazil: score(0.57), .english: score(0.28), .spanish: score(0.75)]
        #expect(SpokenLanguageIdentifier.pick(scores, first: .portugueseBrazil) == nil)
    }

    @Test func theFirstKeepsANearTie() {
        let scores = [CueLanguage.spanish: score(0.97), .english: score(0.98)]
        #expect(SpokenLanguageIdentifier.pick(scores, first: .spanish) == .spanish)
    }

    /// A Japanese recording: Portuguese and Spanish heard nothing, English a few commas.
    @Test func aLanguageThatHeardAlmostNothingDoesntCount() {
        let scores = [CueLanguage.portugueseBrazil: score(0, 0), .spanish: score(0, 0), .english: score(0.02, 16), .japanese: score(0.95, 56)]
        #expect(SpokenLanguageIdentifier.pick(scores, first: .portugueseBrazil) == .japanese)
        #expect(SpokenLanguageIdentifier.pick([.english: score(0.9, 2), .spanish: score(0.8, 1)], first: .english) == nil)
    }

    @Test func eachLanguageHearsTheSpeechAndOnlyTheFirstMayDownload() async throws {
        let audio = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-en-US", withExtension: "m4a"))
        let listener = FakeSpokenLanguageListener([.portugueseBrazil: score(0.83), .english: score(0.98), .spanish: score(0.95)])
        let identifier = SpokenLanguageIdentifier(listener: listener)
        let found = try await identifier.spokenLanguage(in: audio, among: [.portugueseBrazil, .english, .spanish])
        #expect(found == .english)
        #expect(listener.calls.map(\.0) == [.portugueseBrazil, .english, .spanish])
        #expect(listener.calls.map(\.1) == [true, false, false])
    }

    /// The first can't be judged (a dictation model, or no model): the take is heard in it, as asked.
    @Test func withoutTheFirstNothingIsCompared() async throws {
        let audio = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-en-US", withExtension: "m4a"))
        let listener = FakeSpokenLanguageListener([.english: score(0.98)])
        let found = try await SpokenLanguageIdentifier(listener: listener).spokenLanguage(in: audio, among: [.portugueseBrazil, .english])
        #expect(found == nil)
        #expect(listener.calls.count == 1)
    }

    /// A language that fails to listen only drops out; captions never fail for it.
    @Test func aLanguageThatFailsToListenDropsOut() async throws {
        let audio = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-en-US", withExtension: "m4a"))
        let listener = FakeSpokenLanguageListener([.portugueseBrazil: score(0.83), .english: score(0.98)], failing: [.english])
        let identifier = SpokenLanguageIdentifier(listener: listener)
        #expect(try await identifier.spokenLanguage(in: audio, among: [.portugueseBrazil, .english]) == .portugueseBrazil)
        let failingFirst = FakeSpokenLanguageListener([.english: score(0.98)], failing: [.portugueseBrazil])
        #expect(try await SpokenLanguageIdentifier(listener: failingFirst).spokenLanguage(in: audio, among: [.portugueseBrazil, .english]) == nil)
    }

    @Test func silenceAndASingleLanguageAreNeverHeard() async throws {
        let silent = URL.temporaryDirectory.appending(path: "silent-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: silent) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000 * 3))
        buffer.frameLength = buffer.frameCapacity
        try AVAudioFile(forWriting: silent, settings: format.settings).write(from: buffer)
        let listener = FakeSpokenLanguageListener([.english: score(0.98), .spanish: score(0.5)])
        let identifier = SpokenLanguageIdentifier(listener: listener)
        #expect(try await identifier.spokenLanguage(in: silent, among: [.english, .spanish]) == nil)
        let audio = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-en-US", withExtension: "m4a"))
        #expect(try await identifier.spokenLanguage(in: audio, among: [.english]) == nil)
        #expect(listener.calls.isEmpty)
    }
}
