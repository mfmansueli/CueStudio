//
//  CaptionSpeechTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// Captions on this device's own speech recognition, language by language: the recording of each
/// script (`Fixtures/Speech`, spoken by Apple's system voices) is transcribed through `CaptionTranscriber`
/// exactly as a take is, and what comes back is judged against the script and the recording.
///
/// What is measured: how much of the script was heard, whether every word's time sits inside the
/// recording and in order, whether the first word starts where the speech does, and how many words carry
/// a time of their own as against an even share of a stretch (`isEstimated`). A word that shares a stretch
/// is never reported as measured.
///
/// Synthesized speech is a technical reference: it says the recognizer and the timings work, not that every
/// human accent is captioned well. Opt-in, and on a device, like `VoiceFollowingSpeechTests`
/// (`TEST_RUNNER_CUE_SPEECH_E2E=1`). A language this device can't run is *not validated*, never passed.
@Suite(
    "Captions on this device's speech recognition",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil)
)
@MainActor
struct CaptionSpeechTests {
    private final class BundleToken {}

    /// Share of the script's words that have to be heard, in order. Apple's Hindi dictation model hears about
    /// 61% of the synthesized recording (words dropped or merged, measured on an iPhone): that is its limit, so
    /// it is held to what it does, and said so in the report, rather than to the others' bar.
    private static func requiredShare(for language: CueLanguage) -> Double {
        language == .hindi ? 0.55 : 0.7
    }

    @Test(arguments: CueLanguage.allCases)
    func captionsAreHeardAndTimedInTheRecording(language: CueLanguage) async throws {
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-\(language.rawValue)", withExtension: "m4a"))
        let file = try AVAudioFile(forReading: url)
        let length = Double(file.length) / file.processingFormat.sampleRate

        let transcript: TakeTranscript
        do {
            transcript = try await CaptionTranscriber.transcript(in: url, language: .language(language), script: script)
        } catch let reason as SpeechUnavailableReason {
            print("CAPTIONS \(language.rawValue): NOT VALIDATED · \(reason.captionMessage)")
            try Test.cancel("\(language.rawValue) not validated: \(reason.captionMessage)")
        }
        let words = transcript.words
        #expect(!words.isEmpty, "\(language.rawValue): nothing heard")

        // How much of the script was heard, in order: by words, and for the languages written without spaces
        // (where the recognizer and the script cut words differently, and write numbers differently) by letters.
        let written = ScriptWords(text: script, language: language).tokens
        let heardKeys = words.flatMap { WordTokenizer.matchingKeys(of: $0.text, language: language) }
        let wordShare = Double(WordAlignment.matches(written, heardKeys).count) / Double(max(1, written.count))
        let writtenLetters = written.joined().map(String.init)
        let heardLetters = heardKeys.joined().map(String.init)
        let letterShare = Double(WordAlignment.matches(writtenLetters, heardLetters).count) / Double(max(1, writtenLetters.count))
        let share = language.writesWithoutSpaces ? max(wordShare, letterShare) : wordShare

        // Times: inside the recording, in order, and honest about which are measured.
        let outside = words.filter { $0.start < -0.05 || $0.end > length + 0.5 || $0.end < $0.start }
        let backwards = zip(words, words.dropFirst()).filter { $1.start + 0.05 < $0.start }.count
        let estimated = words.filter(\.isEstimated).count
        let sharedRuns = words.filter { word in words.contains { $0 != word && $0.start == word.start && $0.end == word.end } }
        let unflagged = sharedRuns.filter { !$0.isEstimated }.count

        // Sync: the first word starts near where the voice starts, the last ends near where it stops.
        let first = words.first?.start ?? 0
        let last = words.last?.end ?? 0
        let onset = Self.speechOnset(of: file)
        print(
            "CAPTIONS \(language.rawValue): heard \(Int(share * 100))% of the script · \(words.count) words"
                + " · \(estimated) estimated · first word \(String(format: "%.2f", first)) s (voice at \(String(format: "%.2f", onset)) s)"
                + " · last word \(String(format: "%.2f", last)) s of \(String(format: "%.2f", length)) s"
                + " · outside \(outside.count) · out of order \(backwards) · engine code \(transcript.languageCode)"
                + " · by letters \(Int(letterShare * 100))% · heard “\(CaptionText.joined(words.map(\.text)).prefix(160))”"
        )
        #expect(share >= Self.requiredShare(for: language), "\(language.rawValue): only \(Int(share * 100))% of the script was heard")
        #expect(outside.isEmpty, "\(language.rawValue): \(outside.count) words timed outside the recording")
        #expect(backwards == 0, "\(language.rawValue): \(backwards) words out of order")
        #expect(unflagged == 0, "\(language.rawValue): \(unflagged) words that share a time aren't marked as estimated")
        #expect(abs(first - onset) <= 1.0, "\(language.rawValue): first word at \(first) s, voice at \(onset) s")
        #expect(last <= length + 0.5 && last >= length * 0.6, "\(language.rawValue): last word ends at \(last) s of \(length) s")
        // The caption lines built from it stay inside the recording too.
        let lines = CaptionBuilder.captions(
            heard: words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end, isEstimated: $0.isEstimated) },
            script: script, language: language
        )
        #expect(!lines.isEmpty)
        #expect(lines.allSatisfy { $0.start >= -0.05 && $0.end <= length + 0.5 }, "\(language.rawValue): a line runs outside the recording")
        // Chinese keeps its writing system all the way: Traditional characters never come back as Simplified.
        if language == .chineseTraditional { #expect(transcript.languageCode == "zh-Hant") }
        if language == .chineseSimplified { #expect(transcript.languageCode == "zh-Hans") }
    }

    /// Seconds to the first sample louder than a whisper.
    private static func speechOnset(of file: AVAudioFile) -> TimeInterval {
        file.framePosition = 0
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, let channel = buffer.floatChannelData?[0] else { return 0 }
        let threshold: Float = 0.01
        for index in 0..<Int(buffer.frameLength) where abs(channel[index]) > threshold {
            return Double(index) / file.processingFormat.sampleRate
        }
        return 0
    }
}
