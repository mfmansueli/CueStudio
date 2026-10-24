//
//  EditByTextDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Edit by text end to end on this device's speech recognition: a take made of each recording of the run's voice (`SpeechSample`) is
/// transcribed like a take, three words in the middle are cut by text exactly as the sheet does it (`TranscriptEditing`), the
/// edit is exported, and the export is listened to again: the three words are gone, the words around them stay, and the video
/// is shorter by the cut. Opt-in, on a device (`CUE_DEVICE=… scripts/test.sh device EditByTextDeviceTests`); a language this
/// device can't run is not validated, never passed.
@Suite(
    "Edit by text on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil),
    .timeLimit(.minutes(5))
)
@MainActor
struct EditByTextDeviceTests {
    @Test(arguments: [CueLanguage.portugueseBrazil, .english])
    func cuttingThreeWordsByTextRemovesThemFromTheExport(language: CueLanguage) async throws {
        KeepScreenAwake.enable()
        for sample in try SpeechSample.samples(of: language) {
            try await cutThreeWords(sample)
        }
    }

    private func cutThreeWords(_ sample: SpeechSample) async throws {
        let language = sample.language
        let script = sample.script
        let speech = sample.url
        let length = try await AVURLAsset(url: speech).load(.duration).seconds
        let take = try await Self.take(speaking: speech, seconds: Int(length.rounded(.up)))
        defer { try? FileManager.default.removeItem(at: take) }

        let heard: TakeTranscript
        do {
            heard = try await CaptionTranscriber.transcript(in: speech, language: .language(language), script: script)
        } catch let reason as SpeechUnavailableReason {
            print("EDIT BY TEXT \(language.rawValue): NOT VALIDATED · \(reason.captionMessage)")
            try Test.cancel("\(language.rawValue) not validated: \(reason.captionMessage)")
        }
        let words = heard.words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end) }
        try #require(words.count >= 9, "\(sample.label): only \(words.count) words heard")

        // Three words in the middle, picked as the sheet picks them (first, then last).
        let first = words.count / 2 - 1
        let listed = words.enumerated().map { index, word in
            TranscriptWord(
                id: "\(index)", text: word.text, sourceID: nil, span: TimeSpan(start: word.start, end: word.end), index: index,
                segmentID: nil, editedStart: word.start
            )
        }
        let cut = TranscriptEditing.cut(from: listed[first], to: listed[first + 2], transcript: words, recordingLength: length)
        let phrase = words[first...(first + 2)].map(\.text)
        var edit = TakeEdit(sourceDuration: length, aspect: .portrait)
        edit.voiceEnhancement = .off
        let removed = edit.timeline.remove([cut])
        #expect(removed)

        let started = ProcessInfo.processInfo.systemUptime
        let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
            videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 1080, frameRate: 30)
        )
        let exportSeconds = ProcessInfo.processInfo.systemUptime - started
        defer { try? FileManager.default.removeItem(at: output) }
        let exported = try await AVURLAsset(url: output).load(.duration).seconds
        #expect(abs(exported - (length - cut.duration)) < 0.15, "\(sample.label): \(exported) s vs \(length - cut.duration) s")

        // Listened to again: the phrase is gone, its neighbours stay.
        let audio = try await AudioTrackExtractor.extract(from: output)
        defer { try? FileManager.default.removeItem(at: audio) }
        let again = try await CaptionTranscriber.transcript(in: audio, language: .language(language), script: script)
        let keys = again.words.flatMap { WordTokenizer.matchingKeys(of: $0.text, language: language) }
        let cutKeys = phrase.flatMap { WordTokenizer.matchingKeys(of: $0, language: language) }
        // The nearest word of three letters or more on each side: a recognizer hearing a cut drops or merges a short word at the
        // join ("um copo pegar" for "um copo de pegar", whose "de" is in the sound), which says nothing about the cut.
        let isWord = { (word: CaptionWord) in word.text.filter(\.isLetter).count >= 3 || language.writesWithoutSpaces }
        let neighbourBefore = words[..<first].last(where: isWord) ?? words[first - 1]
        let neighbourAfter = words[(first + 3)...].first(where: isWord) ?? words[first + 3]
        let before = WordTokenizer.matchingKeys(of: neighbourBefore.text, language: language)
        let after = WordTokenizer.matchingKeys(of: neighbourAfter.text, language: language)
        let phraseGone = !Self.contains(keys, run: cutKeys)
        let neighboursKept = before.allSatisfy(keys.contains) && after.allSatisfy(keys.contains)
        print(
            "EDIT BY TEXT \(language.rawValue) \(sample.label): cut “\(phrase.joined(separator: " "))” (\(String(format: "%.2f", cut.duration)) s)"
                + " · video \(String(format: "%.1f", length)) → \(String(format: "%.1f", exported)) s · export \(String(format: "%.1f", exportSeconds)) s"
                + " · phrase gone \(phraseGone) · neighbours kept \(neighboursKept)"
                + " · around “\(neighbourBefore.text) | \(neighbourAfter.text)” · heard after “\(CaptionText.joined(again.words.map(\.text)))”"
        )
        #expect(phraseGone, "\(sample.label): “\(phrase.joined(separator: " "))” still heard in the export")
        if sample.voice == .human, language == .portugueseBrazil {
            // Measured on an iPhone: Portuguese's recognizer puts the edges of words read fluently by people up to ~150 ms off
            // ("maneira" timed 0.18 s long), so a cut at them clips the next word's first sound in every reading. English is clean.
            withKnownIssue("Portuguese word edges from people's fluent speech are off (LOCALIZATION.md §5)", isIntermittent: true) {
                #expect(neighboursKept, "\(sample.label): a word next to the cut is missing from the export")
            }
        } else {
            #expect(neighboursKept, "\(sample.label): a word next to the cut is missing from the export")
        }
    }

    /// The same on the creator's own takes on this iPhone, never touching them: each recording is COPIED to the temporary
    /// folder and only the copy is transcribed, cut and exported (the library and its files are only read). Opt-in on top of
    /// the suite: `TEST_RUNNER_CUE_REAL_TAKES=pt-BR` (the language the takes are spoken in). Up to the 3 newest takes.
    @Test func cuttingByTextWorksOnTheTakesOnThisIPhone() async throws {
        guard let code = ProcessInfo.processInfo.environment["CUE_REAL_TAKES"], let language = CueLanguage(rawValue: code) else {
            try Test.cancel("Set TEST_RUNNER_CUE_REAL_TAKES=<language> to run on this iPhone's own takes")
        }
        KeepScreenAwake.enable()
        let folder = URL.applicationSupportDirectory.appending(path: "Takes", directoryHint: .isDirectory)
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles
        )) ?? []).filter { ["mov", "mp4"].contains($0.pathExtension.lowercased()) }
        let newest = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }.prefix(3)
        try #require(!newest.isEmpty, "No takes on this iPhone")
        for original in newest {
            let copy = URL.temporaryDirectory.appending(path: "copy-\(UUID().uuidString).\(original.pathExtension)")
            try FileManager.default.copyItem(at: original, to: copy)
            defer { try? FileManager.default.removeItem(at: copy) }
            let asset = AVURLAsset(url: copy)
            let length = try await asset.load(.duration).seconds
            let size = try await asset.loadTracks(withMediaType: .video).first?.load(.naturalSize) ?? .zero
            let audio = try await AudioTrackExtractor.extract(from: copy)
            defer { try? FileManager.default.removeItem(at: audio) }
            let heard = try await CaptionTranscriber.transcript(in: audio, language: .language(language), script: "")
            let words = heard.words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end) }
            guard words.count >= 9 else {
                print("EDIT BY TEXT REAL \(original.lastPathComponent): only \(words.count) words heard, skipped")
                continue
            }
            let first = words.count / 2 - 1
            let listed = words.enumerated().map { index, word in
                TranscriptWord(
                    id: "\(index)", text: word.text, sourceID: nil, span: TimeSpan(start: word.start, end: word.end), index: index,
                    segmentID: nil, editedStart: word.start
                )
            }
            let cut = TranscriptEditing.cut(from: listed[first], to: listed[first + 2], transcript: words, recordingLength: length)
            let phrase = words[first...(first + 2)].map(\.text)
            var edit = TakeEdit(sourceDuration: length, aspect: .portrait)
            edit.voiceEnhancement = .soft
            let removed = edit.timeline.remove([cut])
            #expect(removed)
            let started = ProcessInfo.processInfo.systemUptime
            let output = try await VideoExportService(sounds: RecordingSoundCache()).export(
                videoAt: copy, options: ExportOptions(aspect: .portrait, edit: edit, shortSide: 1080, frameRate: 30)
            )
            let took = ProcessInfo.processInfo.systemUptime - started
            defer { try? FileManager.default.removeItem(at: output) }
            let exported = try await AVURLAsset(url: output).load(.duration).seconds
            let exportedAudio = try await AudioTrackExtractor.extract(from: output)
            defer { try? FileManager.default.removeItem(at: exportedAudio) }
            let again = try await CaptionTranscriber.transcript(in: exportedAudio, language: .language(language), script: "")
            let keys = again.words.flatMap { WordTokenizer.matchingKeys(of: $0.text, language: language) }
            let cutKeys = phrase.flatMap { WordTokenizer.matchingKeys(of: $0, language: language) }
            let phraseGone = !Self.contains(keys, run: cutKeys)
            print(
                "EDIT BY TEXT REAL \(original.lastPathComponent): \(Int(size.width))×\(Int(size.height)) · \(words.count) words heard"
                    + " · cut “\(phrase.joined(separator: " "))” (\(String(format: "%.2f", cut.duration)) s)"
                    + " · \(String(format: "%.1f", length)) → \(String(format: "%.1f", exported)) s · export 1080p \(String(format: "%.1f", took)) s"
                    + " · phrase gone \(phraseGone) · heard after \(again.words.count) words"
            )
            #expect(abs(exported - (length - cut.duration)) < 0.15)
            #expect(phraseGone, "“\(phrase.joined(separator: " "))” still heard in the export of \(original.lastPathComponent)")
        }
    }

    /// Whether `run` appears in `keys` in a row.
    private static func contains(_ keys: [String], run: [String]) -> Bool {
        guard !run.isEmpty, keys.count >= run.count else { return false }
        return (0...(keys.count - run.count)).contains { Array(keys[$0..<($0 + run.count)]) == run }
    }

    /// A take that shows plain frames and plays `speech` as its sound.
    private static func take(speaking speech: URL, seconds: Int) async throws -> URL {
        let frames = try await TestFootage.make(seconds: seconds, width: 1080, height: 1920)
        defer { try? FileManager.default.removeItem(at: frames) }
        let composition = AVMutableComposition()
        let picture = AVURLAsset(url: frames)
        let sound = AVURLAsset(url: speech)
        let length = try await sound.load(.duration)
        guard let videoTrack = try await picture.loadTracks(withMediaType: .video).first,
              let audioTrack = try await sound.loadTracks(withMediaType: .audio).first,
              let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw CocoaError(.fileReadCorruptFile) }
        try video.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: videoTrack, at: .zero)
        try audio.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: audioTrack, at: .zero)
        let url = URL.temporaryDirectory.appending(path: "speaking-take-\(UUID().uuidString).mov")
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try await session.export(to: url, as: .mov)
        return url
    }
}
