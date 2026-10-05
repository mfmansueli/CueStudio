//
//  VoiceFollowingSpeechTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// Voice Following end to end, on the device's own speech recognition: a recording of each script
/// (`Fixtures/Speech`, spoken by the system voices) goes through `SpeechRecognitionManager` exactly
/// as the microphone does, and the tracker has to follow it to the end.
///
/// Opt-in, because the first run downloads each language's speech model, and on a device: the
/// simulator lists speech models but can't run them (each language then reports no recognition).
/// `TEST_RUNNER_CUE_SPEECH_E2E=1 xcodebuild … -destination 'platform=iOS,name=<iPhone>'
/// -only-testing:"Cue StudioTests/VoiceFollowingSpeechTests" test`.
/// A language this device can't recognize is reported, never replaced by another.
@MainActor
@Suite(
    "Voice Following on this device's speech recognition",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil)
)
struct VoiceFollowingSpeechTests {
    static let scripts: [CueLanguage: String] = [
        .english: "Here are three habits that changed my mornings. First, I drink a glass of water before I touch my phone. Second, I write down one thing I want to finish today.",
        .spanish: "Estos son tres hábitos que cambiaron mis mañanas. Primero, bebo un vaso de agua antes de mirar el móvil. Segundo, escribo una cosa que quiero terminar hoy.",
        .portugueseBrazil: "Esses são três hábitos que mudaram as minhas manhãs. Primeiro, eu bebo um copo de água antes de pegar no celular. Segundo, eu anoto uma coisa que quero terminar hoje.",
        .french: "Voici trois habitudes qui ont changé mes matins. D'abord, je bois un verre d'eau avant de toucher mon téléphone. Ensuite, j'écris une chose que je veux finir aujourd'hui.",
        .german: "Das sind drei Gewohnheiten, die meine Morgen verändert haben. Erstens trinke ich ein Glas Wasser, bevor ich mein Handy anfasse. Zweitens schreibe ich eine Sache auf, die ich heute erledigen will.",
        .italian: "Queste sono tre abitudini che hanno cambiato le mie mattine. Primo, bevo un bicchiere d'acqua prima di prendere il telefono. Secondo, scrivo una cosa che voglio finire oggi.",
        .japanese: "朝の習慣を三つ紹介します。まず、スマホを見る前に水を一杯飲みます。次に、今日終わらせたいことを一つ書き出します。",
        .korean: "제 아침을 바꾼 세 가지 습관을 소개할게요. 먼저 휴대폰을 보기 전에 물을 한 잔 마셔요. 그다음 오늘 끝내고 싶은 일을 하나 적어요.",
        .chineseSimplified: "这是改变我早晨的三个习惯。第一，我在看手机之前先喝一杯水。第二，我写下今天想完成的一件事。",
        .hindi: "ये तीन आदतें हैं जिन्होंने मेरी सुबह बदल दी। पहली, फ़ोन देखने से पहले मैं एक गिलास पानी पीती हूँ। दूसरी, मैं एक काम लिखती हूँ जो आज पूरा करना है।",
        .indonesian: "Ini tiga kebiasaan yang mengubah pagi saya. Pertama, saya minum segelas air sebelum memegang ponsel. Kedua, saya menulis satu hal yang ingin saya selesaikan hari ini.",
        .arabic: "هذه ثلاث عادات غيرت صباحي. أولا، أشرب كوبا من الماء قبل أن ألمس هاتفي. ثانيا، أكتب شيئا واحدا أريد أن أنهيه اليوم.",
        .turkish: "Sabahlarımı değiştiren üç alışkanlık var. İlk olarak, telefonuma dokunmadan önce bir bardak su içiyorum. İkinci olarak, bugün bitirmek istediğim bir şeyi yazıyorum.",
        .thai: "นี่คือสามนิสัยที่เปลี่ยนตอนเช้าของฉัน อย่างแรก ฉันดื่มน้ำหนึ่งแก้วก่อนจับโทรศัพท์ อย่างที่สอง ฉันเขียนสิ่งหนึ่งที่อยากทำให้เสร็จวันนี้",
        .vietnamese: "Đây là ba thói quen đã thay đổi buổi sáng của tôi. Đầu tiên, tôi uống một cốc nước trước khi cầm điện thoại. Thứ hai, tôi viết ra một việc muốn làm xong hôm nay.",
        .dutch: "Dit zijn drie gewoontes die mijn ochtenden hebben veranderd. Eerst drink ik een glas water voordat ik mijn telefoon aanraak. Daarna schrijf ik één ding op dat ik vandaag wil afmaken.",
        .swedish: "Det här är tre vanor som har förändrat mina morgnar. Först dricker jag ett glas vatten innan jag rör telefonen. Sedan skriver jag upp en sak som jag vill bli klar med idag.",
        .danish: "Det er tre vaner, der har ændret mine morgener. Først drikker jeg et glas vand, før jeg rører min telefon. Bagefter skriver jeg én ting ned, som jeg vil have færdig i dag.",
        .norwegian: "Dette er tre vaner som har endret morgenene mine. Først drikker jeg et glass vann før jeg tar på telefonen. Deretter skriver jeg ned én ting som jeg vil bli ferdig med i dag.",
        .chineseTraditional: "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。第二，我寫下今天想完成的一件事。",
    ]

    /// Share of the script's words the reading has to reach.
    private static let required = 0.8

    private final class BundleToken {}

    /// What the tracker saw, shared with the task reading the transcripts.
    private final class Reading {
        var tracker: ScriptSpeechTracker
        var lastHeard = ""
        var updates = 0
        var maxJump = 0
        var backwards = 0
        /// How far the text got while only silence had been played.
        var positionInLeadingSilence = 0
        init(words: [String], language: CueLanguage) { tracker = ScriptSpeechTracker(words: words, language: language) }

        func hear(_ transcript: String) {
            lastHeard = transcript
            let before = tracker.position
            tracker.hear(transcript)
            updates += 1
            maxJump = max(maxJump, tracker.position - before)
            if tracker.position < before { backwards += 1 }
        }
    }

    /// A language this device can't run is *not validated*, never counted as passed: the test is
    /// cancelled (reported as skipped) with the reason, and the line below goes to the log.
    private func notValidated(_ language: CueLanguage, _ reason: String) throws -> Never {
        print("VOICE FOLLOWING \(language.rawValue): NOT VALIDATED · \(reason)")
        try Test.cancel("\(language.rawValue) not validated: \(reason)")
    }

    @Test(arguments: CueLanguage.allCases)
    func followsAReadingOfTheScript(in language: CueLanguage) async throws {
        KeepScreenAwake.enable()
        let script = try #require(Self.scripts[language], "\(language.rawValue) has no script")
        let resource = "speech-\(language.rawValue)"
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: resource, withExtension: "m4a"), "\(language.rawValue) has no recording")
        let speech = SpeechRecognitionManager()
        defer { speech.stop() }

        let transcription: SpeechTranscription
        switch await speech.start(script: script, language: .language(language)) {
        case .listening(let started, let route):
            transcription = started
            // Recognized in the language asked for, and no other.
            #expect(route.language == language)
            #expect(language.accepts(route.locale))
            print("VOICE FOLLOWING \(language.rawValue): \(route.engine) \(route.locale.identifier(.bcp47))")
        case .unavailable(.noRecognition):
            // The simulator lists speech models it can't run: this test needs a device.
            try notValidated(language, "no speech recognition on this device")
        case .unavailable(let reason):
            // Not offered here, or its model couldn't be downloaded: nothing was recognized, so nothing is claimed.
            try notValidated(language, reason.message)
        case .cancelled:
            try notValidated(language, "the recognizer was cancelled before it started")
        }

        let words = ScriptWords(text: script, language: language)
        let reading = Reading(words: words.tokens, language: language)
        let listener = Task { @MainActor in
            for await heard in transcription.transcripts { reading.hear(heard) }
        }
        defer { listener.cancel() }

        // A second of silence first: nothing may move while nobody speaks.
        try await silence(1, into: transcription)
        reading.positionInLeadingSilence = reading.tracker.position
        try await play(url, into: transcription)
        for _ in 0..<150 where reading.tracker.position < words.count {
            try await Task.sleep(for: .milliseconds(100))
        }
        let reached = Double(reading.tracker.position) / Double(max(1, words.count))
        print(
            "VOICE FOLLOWING \(language.rawValue): \(reading.tracker.position)/\(words.count) words"
                + " · largest jump \(reading.maxJump) · backwards \(reading.backwards) · moved in silence \(reading.positionInLeadingSilence)"
                + " · updates \(reading.updates) · heard “\(reading.lastHeard)”"
        )
        #expect(reached >= Self.required, "\(language.rawValue) reached \(reading.tracker.position) of \(words.count) words; heard: \(reading.lastHeard)")
        #expect(reading.positionInLeadingSilence == 0, "\(language.rawValue): the text moved during silence")
        #expect(reading.backwards == 0)
        #expect(reading.tracker.position <= words.count)
    }

    /// What this device offers for each language, asked without downloading anything: ready,
    /// downloads the first time, or not available, and through which recognizer.
    @Test func availabilityOnThisDevice() async {
        let speech = SpeechRecognitionManager()
        let resolver = SpeechLocaleResolver()
        var lines: [String] = []
        for language in CueLanguage.allCases {
            let availability = await speech.availability(of: language)
            let engine: String = switch await resolver.resolve(.language(language)) {
            case .success(let route): "\(route.engine) \(route.locale.identifier(.bcp47))"
            case .failure: "no recognizer"
            }
            lines.append("\(language.rawValue): \(availability) (\(engine))")
        }
        print("VOICE AVAILABILITY \(lines.joined(separator: " · "))")
    }

    private func silence(_ seconds: Double, into transcription: SpeechTranscription) async throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false))
        let chunk = AVAudioFrameCount(format.sampleRate / 10)
        for _ in 0..<Int(seconds * 10) {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return }
            buffer.frameLength = chunk
            transcription.audio(buffer)
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Feeds the recording in 100 ms buffers at four times real speed, then a second of silence so
    /// the last words are finalized, like the microphone would.
    private func play(_ url: URL, into transcription: SpeechTranscription) async throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let chunk = AVAudioFrameCount(format.sampleRate / 10)
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return }
            try file.read(into: buffer, frameCount: chunk)
            transcription.audio(buffer)
            try await Task.sleep(for: .milliseconds(25))
        }
        for _ in 0..<10 {
            guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return }
            silence.frameLength = chunk
            transcription.audio(silence)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
