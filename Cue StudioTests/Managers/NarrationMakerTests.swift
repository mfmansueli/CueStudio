//
//  NarrationMakerTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Text to speech's sound (`NarrationMaker`): the voice's silence at the ends goes, the speed asked for is the speed it plays
/// at (1.5× is two thirds as long), it's brought to a clear voice's level under the ceiling, it lands in the edit's media as a
/// voice-over file, the preview is the first sentence, and a cancel leaves nothing behind.
@Suite("Narration maker", .serialized)
struct NarrationMakerTests {
    private let text = "Hoje eu vou te mostrar três jeitos simples de gravar vídeos melhores com o celular."

    private func narration(speed: Double = 1) -> SpokenNarration {
        SpokenNarration(text: text, voiceID: "pt.felipe", language: "pt-BR", speed: speed)
    }

    @Test(arguments: [1.0, 0.75, 1.5])
    func playsAtTheSpeedAskedWithoutTheSilenceAround(_ speed: Double) async throws {
        let made = try await NarrationMaker.make(narration(speed: speed), speaker: FakeNarrationSpeaker())
        defer { EditMediaFiles.remove([made.fileName]) }
        #expect(made.fileName.hasSuffix(".m4a"))
        #expect(EditMediaFiles.exists(made.fileName))
        let expected = (FakeNarrationSpeaker.spokenLength(of: text) + 2 * NarrationMaker.edgePad) / speed
        #expect(abs(made.duration - expected) / expected < 0.03)
        let url = EditMediaFiles.url(for: made.fileName)
        #expect(abs(try TestTone.duration(of: url) - made.duration) < 0.05)
        // At a clear voice's level, never over the ceiling.
        let level = try #require(try SpeechLoudness.level(ofAudio: url))
        #expect(abs(level - NarrationMaker.speechLevel) < 1.5)
        #expect(try AudioCeiling.peak(of: url) <= AudioCeiling.ceiling + 0.01)
    }

    @Test func thePreviewIsTheFirstSentence() async throws {
        let speaker = FakeNarrationSpeaker()
        let first = "Primeira frase curta."
        let url = try await NarrationMaker.preview(
            SpokenNarration(text: "\(first) Depois vem a segunda, bem mais longa do que a primeira.", voiceID: "pt.felipe", language: "pt-BR"),
            speaker: speaker
        )
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(speaker.texts == [first])
        #expect(NarrationMaker.excerpt(of: String(repeating: "palavra ", count: 60)).count <= NarrationMaker.previewCharacters)
        #expect(!NarrationMaker.excerpt(of: String(repeating: "palavra ", count: 60)).hasSuffix("palavr"))
    }

    @Test func aCancelLeavesNothingBehind() async throws {
        let before = narrationFiles()
        let work = Task { try await NarrationMaker.make(narration(), speaker: FakeNarrationSpeaker(delay: .seconds(5))) }
        try await Task.sleep(for: .milliseconds(100))
        work.cancel()
        await #expect(throws: CancellationError.self) { try await work.value }
        #expect(narrationFiles().subtracting(before).isEmpty)
    }

    /// The files a narration can leave: voice-overs in the edit's media and its sound in the temporary folder. Only those, since
    /// other suites running alongside add their own videos and sounds to the same folders.
    private func narrationFiles() -> Set<String> {
        func names(in folder: URL) -> [String] {
            (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        }
        return Set(names(in: EditMediaFiles.directory).filter { $0.hasSuffix(".m4a") })
            .union(names(in: URL.temporaryDirectory).filter { $0.hasPrefix("Cue-speech-") })
    }

    @Test func voicesAreOfferedBestFirst() {
        let ordered = NarrationVoice.ordered(FakeNarrationSpeaker.voicesOnDevice.filter { $0.language == "pt-BR" })
        #expect(ordered.map(\.name) == ["Felipe", "Luciana"])
        #expect(ordered[0].title.hasPrefix("Felipe · "))
        #expect(ordered[1].title == "Luciana")
        #expect(SpokenNarration(text: "a", voiceID: "v", language: "pt-BR", speed: 4).speed == SpokenNarration.speedRange.upperBound)
    }

    @Test func atTheSameQualityTheLanguagesDefaultComesFirstAndEloquenceLast() {
        let voices = [
            NarrationVoice(id: "eddy", name: "Eddy", language: "pt-BR", quality: .standard, isEloquence: true),
            NarrationVoice(id: "ana", name: "Ana", language: "pt-BR", quality: .standard),
            NarrationVoice(id: "luciana", name: "Luciana", language: "pt-BR", quality: .standard, isSystemDefault: true),
            NarrationVoice(id: "felipe", name: "Felipe", language: "pt-BR", quality: .enhanced),
        ]
        #expect(NarrationVoice.ordered(voices).map(\.name) == ["Felipe", "Luciana", "Ana", "Eddy"])
    }
}
