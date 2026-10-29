//
//  AudioMixDeviceTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// Phase 8's sound on this iPhone, where the Simulator can't tell:
/// - Text to speech: the best voice this iPhone has in Portuguese, English and Spanish says a creator's paragraph at each speed;
///   this iPhone's own speech recognition (as Auto captions hears a take, without the text as a hint) says how much of it is
///   understood, the length says the speed is exact, and how long the voice-over took to make is printed;
/// - Voice effects: the same English paragraph through each effect at its starting amount, heard the same way (a creative effect
///   may cost some words; Radio, Megaphone, Echo and Big hall must keep most), with the time each one takes;
/// - the music library: how long each bundled track takes to open and decode whole on this iPhone (what ▶ waits for at most).
///
/// Opt-in and on a device: `CUE_DEVICE=<iPhone> scripts/test.sh device AudioMixDeviceTests` (`TEST_RUNNER_CUE_AUDIO_E2E=1`). A
/// language this iPhone has no voice or no recognizer for is *not validated*, never passed.
@MainActor
@Suite(
    "Audio mix on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_AUDIO_E2E"] != nil)
)
struct AudioMixDeviceTests {
    private static let paragraphs: [CueLanguage: String] = [
        .portugueseBrazil: "Hoje eu vou mostrar três hábitos que mudaram as minhas manhãs. O primeiro é simples: acordar sempre no mesmo "
            + "horário, até no fim de semana. O segundo é beber um copo de água antes do café.",
        .english: "Today I want to show you three habits that changed my mornings. The first one is simple: wake up at the same time "
            + "every day, even on weekends. The second is to drink a glass of water before your coffee.",
        .spanish: "Hoy te quiero mostrar tres hábitos que cambiaron mis mañanas. El primero es simple: despertarte siempre a la misma "
            + "hora, incluso los fines de semana. El segundo es tomar un vaso de agua antes del café.",
    ]

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// The voice the sheet offers first in `language`; cancels the test when this iPhone has none.
    private func bestVoice(_ language: CueLanguage) throws -> NarrationVoice {
        let voices = SystemNarrationSpeaker().voices().filter { $0.language == language.localeIdentifier }
        guard let voice = NarrationVoice.ordered(voices).first else {
            print("NARRATION \(language.rawValue): NOT VALIDATED · no voice on this iPhone")
            try Test.cancel("\(language.rawValue): no voice on this iPhone")
        }
        return voice
    }

    /// Share of the paragraph's words heard in order, as `CaptionSpeechTests` counts it.
    private func heardShare(of url: URL, language: CueLanguage) async throws -> (share: Double, heard: String) {
        let transcript: TakeTranscript
        do {
            transcript = try await CaptionTranscriber.transcript(in: url, language: .language(language))
        } catch let reason as SpeechUnavailableReason {
            print("HEARING \(language.rawValue): NOT VALIDATED · \(reason.captionMessage)")
            try Test.cancel("\(language.rawValue): \(reason.captionMessage)")
        }
        let script = Self.paragraphs[language] ?? ""
        let written = ScriptWords(text: script, language: language).tokens
        let heard = transcript.words.flatMap { WordTokenizer.matchingKeys(of: $0.text, language: language) }
        let share = Double(WordAlignment.matches(written, heard).count) / Double(max(1, written.count))
        return (share, CaptionText.joined(transcript.words.map(\.text)))
    }

    private func length(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    @Test(arguments: [CueLanguage.portugueseBrazil, .english, .spanish])
    func aNarrationIsUnderstoodAtEverySpeed(_ language: CueLanguage) async throws {
        KeepScreenAwake.enable()
        let voice = try bestVoice(language)
        let text = try #require(Self.paragraphs[language])
        var natural: TimeInterval?
        for speed in [1.0, 0.75, 1.25, 1.5] {
            let narration = SpokenNarration(text: text, voiceID: voice.id, language: language.localeIdentifier, speed: speed)
            let started = uptime
            let made: (fileName: String, duration: TimeInterval)
            do {
                made = try await NarrationMaker.make(narration, speaker: SystemNarrationSpeaker())
            } catch {
                let listed = SystemNarrationSpeaker().voices().contains { $0.id == voice.id }
                print("NARRATION \(language.rawValue) \(voice.name) \(speed)×: FAILED \(error) · still listed: \(listed)")
                throw error
            }
            let took = uptime - started
            defer { EditMediaFiles.remove([made.fileName]) }
            let url = EditMediaFiles.url(for: made.fileName)
            let seconds = try length(of: url)
            if speed == 1 { natural = seconds }
            let (share, heard) = try await heardShare(of: url, language: language)
            let ratio = natural.map { $0 / seconds } ?? 1
            print(
                "NARRATION \(language.rawValue) \(voice.name) (\(voice.quality)) \(speed)×: \(String(format: "%.2f", seconds)) s"
                    + " (×\(String(format: "%.3f", ratio)) of 1×) · made in \(String(format: "%.2f", took)) s"
                    + " · heard \(Int((share * 100).rounded()))% · “\(heard.prefix(200))”"
            )
            #expect(abs(ratio - speed) < speed * 0.03, "\(speed)×: the length is ×\(ratio) of 1×")
            #expect(share >= (speed <= 1.25 ? 0.8 : 0.7), "\(language.rawValue) \(speed)×: \(Int(share * 100))% heard")
        }
    }

    @Test func voiceEffectsKeepTheWordsTheyShould() async throws {
        KeepScreenAwake.enable()
        let voice = try bestVoice(.english)
        let narration = SpokenNarration(text: Self.paragraphs[.english] ?? "", voiceID: voice.id, language: "en-US")
        let made = try await NarrationMaker.make(narration, speaker: SystemNarrationSpeaker())
        defer { EditMediaFiles.remove([made.fileName]) }
        let url = EditMediaFiles.url(for: made.fileName)
        let plain = try await heardShare(of: url, language: .english).share
        print("VOICE EFFECT none: heard \(Int((plain * 100).rounded()))% of \(String(format: "%.1f", made.duration)) s")
        for effect in VoiceEffect.allCases {
            let started = uptime
            let rendered = try await VoiceEffectRenderer.render(file: url, setting: VoiceEffectSetting(effect: effect), clip: "device")
            let took = uptime - started
            defer { try? FileManager.default.removeItem(at: rendered) }
            let (share, heard) = try await heardShare(of: rendered, language: .english)
            print(
                "VOICE EFFECT \(effect.rawValue) 70%: heard \(Int((share * 100).rounded()))% · made in \(String(format: "%.2f", took)) s"
                    + " (\(String(format: "%.0f", made.duration / max(took, 0.001)))× real time) · “\(heard.prefix(160))”"
            )
            let renderedLength = try length(of: rendered)
            #expect(abs(renderedLength - made.duration) < 0.05)
            switch effect {
            case .radio, .megaphone, .echo, .hall: #expect(share >= 0.75, "\(effect.rawValue): \(Int(share * 100))% heard")
            case .robot, .deep, .chipmunk: #expect(share >= 0.4, "\(effect.rawValue): \(Int(share * 100))% heard")
            }
        }
    }

    @Test(arguments: CueTrack.allCases)
    func aLibraryTrackDecodesWholeInAMoment(_ track: CueTrack) async throws {
        KeepScreenAwake.enable()
        let started = uptime
        let url = try await CueMusicLibraryFiles().file(for: track)
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let block: AVAudioFrameCount = 65_536
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: block))
        var frames: AVAudioFramePosition = 0
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: block)
            frames += AVAudioFramePosition(buffer.frameLength)
        }
        let took = uptime - started
        let seconds = Double(frames) / format.sampleRate
        print(
            "LIBRARY \(track.rawValue): decoded in \(String(format: "%.2f", took)) s for \(String(format: "%.1f", seconds)) s of music"
                + " (\(String(format: "%.0f", seconds / max(took, 0.001)))× real time)"
        )
        #expect(abs(seconds - track.duration) < 0.02)
        #expect(took < 2, "\(track.rawValue) took \(took) s")
    }
}
