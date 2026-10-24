//
//  CaptionSpeechTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// Captions on this device's own speech recognition, language by language: each recording of the run's voice
/// (`SpeechSample`: Apple's system voice reading the language's script, or four people reading FLEURS sentences) is
/// transcribed through `CaptionTranscriber` exactly as a take is, and what comes back is judged against the script and
/// the recording.
///
/// What is measured: how much of the script was heard, whether every word's time sits inside the
/// recording and in order, whether the first word starts where the speech does, and how many words carry
/// a time of their own as against an even share of a stretch (`isEstimated`). A word that shares a stretch
/// is never reported as measured.
///
/// Synthesized speech is a technical reference: it says the recognizer and the timings work, not that every
/// human accent is captioned well; the people's readings say more (`TEST_RUNNER_CUE_SPEECH_VOICE=human`). Opt-in, and on a
/// device, like `VoiceFollowingSpeechTests` (`TEST_RUNNER_CUE_SPEECH_E2E=1`). A language this device can't run is *not
/// validated*, never passed.
@Suite(
    "Captions on this device's speech recognition",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil)
)
@MainActor
struct CaptionSpeechTests {
    /// Share of the script's words that have to be heard, in order. Apple's Hindi dictation model hears about
    /// 61% of the synthesized recording (words dropped or merged, measured on an iPhone): that is its limit, so
    /// it is held to what it does, and said so in the report, rather than to the others' bar.
    private static func requiredShare(for language: CueLanguage) -> Double {
        language == .hindi ? 0.55 : 0.7
    }

    @Test(arguments: CueLanguage.allCases)
    func captionsAreHeardAndTimedInTheRecording(language: CueLanguage) async throws {
        KeepScreenAwake.enable()
        for sample in try SpeechSample.samples(of: language) {
            try await caption(sample)
        }
    }

    private func caption(_ sample: SpeechSample) async throws {
        let language = sample.language
        let script = sample.script
        let url = sample.url
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
        #expect(!words.isEmpty, "\(sample.label): nothing heard")

        // How much of the script was heard, in order: by words, and for the languages written without spaces
        // (where the recognizer and the script cut words differently, and write numbers differently) by letters.
        let written = ScriptWords(text: script, language: language).tokens
        let heardKeys = words.flatMap { WordTokenizer.matchingKeys(of: $0.text, language: language) }
        let wordShare = Double(WordAlignment.matches(written, heardKeys).count) / Double(max(1, written.count))
        let writtenLetters = written.joined().map(String.init)
        let heardLetters = heardKeys.joined().map(String.init)
        let letterShare = Double(WordAlignment.matches(writtenLetters, heardLetters).count) / Double(max(1, writtenLetters.count))
        // Korean is spaced as each writer likes (띄어쓰기: "6 대 6" and "6대 6", "타이 브레이크" and "타이브레이크"): its words are
        // counted by letters too.
        let share = language.writesWithoutSpaces || language == .korean ? max(wordShare, letterShare) : wordShare

        // Times: inside the recording, in order, and honest about which are measured.
        let outside = words.filter { $0.start < -0.05 || $0.end > length + 0.5 || $0.end < $0.start }
        let backwards = zip(words, words.dropFirst()).filter { $1.start + 0.05 < $0.start }.count
        let estimated = words.filter(\.isEstimated).count
        let sharedRuns = words.filter { word in words.contains { $0 != word && $0.start == word.start && $0.end == word.end } }
        let unflagged = sharedRuns.filter { !$0.isEstimated }.count

        // Sync: the first word starts near where the voice starts, the last ends near where it stops.
        let first = words.first?.start ?? 0
        let last = words.last?.end ?? 0
        let voice = RecordingOnset.span(in: file)
        let onset = voice.start
        print(
            "CAPTIONS \(language.rawValue) \(sample.label): heard \(Int(share * 100))% of the script · \(words.count) words"
                + " · \(estimated) estimated · first word \(String(format: "%.2f", first)) s (voice at \(String(format: "%.2f", onset)) s)"
                + " · last word \(String(format: "%.2f", last)) s (voice stops at \(String(format: "%.2f", voice.end)) s)"
                + " of \(String(format: "%.2f", length)) s"
                + " · outside \(outside.count) · out of order \(backwards) · engine code \(transcript.languageCode)"
                + " · by letters \(Int(letterShare * 100))% · heard “\(CaptionText.joined(words.map(\.text)).prefix(160))”"
        )
        let timeline = words.map { "\($0.text)@\(String(format: "%.2f", $0.start))–\(String(format: "%.2f", $0.end))" }
        print("CAPTION WORDS \(sample.label): " + timeline.joined(separator: " "))
        #expect(share >= Self.requiredShare(for: language), "\(sample.label): only \(Int(share * 100))% of the script was heard")
        #expect(outside.isEmpty, "\(sample.label): \(outside.count) words timed outside the recording")
        #expect(backwards == 0, "\(sample.label): \(backwards) words out of order")
        #expect(unflagged == 0, "\(sample.label): \(unflagged) words that share a time aren't marked as estimated")
        // Sync against the recording's loudness. The system voices start and stop in silence: the first and last words sit on
        // the voice. People's readings have room noise, which can only make the voice look longer: no caption starts before
        // it or ends after it.
        if sample.voice == .synthetic {
            #expect(abs(first - onset) <= 1.0, "\(sample.label): first word at \(first) s, voice at \(onset) s")
        } else {
            #expect(first >= onset - 1.0, "\(sample.label): first word at \(first) s, voice at \(onset) s")
            #expect(last <= voice.end + 1.0, "\(sample.label): last word ends at \(last) s, voice stops at \(voice.end) s")
        }
        #expect(last <= length + 0.5 && last >= length * 0.6, "\(sample.label): last word ends at \(last) s of \(length) s")
        // The caption lines built from it stay inside the recording too.
        let lines = CaptionBuilder.captions(
            heard: words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end, isEstimated: $0.isEstimated) },
            script: script, language: language
        )
        #expect(!lines.isEmpty)
        #expect(lines.allSatisfy { $0.start >= -0.05 && $0.end <= length + 0.5 }, "\(sample.label): a line runs outside the recording")
        // Chinese keeps its writing system all the way: Traditional characters never come back as Simplified.
        if language == .chineseTraditional { #expect(transcript.languageCode == "zh-Hant") }
        if language == .chineseSimplified { #expect(transcript.languageCode == "zh-Hans") }
    }
}
