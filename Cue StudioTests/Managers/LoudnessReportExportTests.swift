//
//  LoudnessReportExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The test bundle, where the FLEURS readings are.
private final class LoudnessBundleToken {}

extension RealExports {
    /// The sound of real exports, kept for measuring (E4 audio: "medir loudness e true peak no arquivo antes de aprovar
    /// normalização"). Four FLEURS readings (two Brazilian Portuguese, two American English: real people) as a narration over a
    /// silent take, exported as a creator leaves them: the narration alone, with a library track added as the editor adds it (40%,
    /// 12 dB down under the voice, staying low in pauses), and the track alone. The take's own voice isn't measured here: the
    /// Simulator won't lay a test picture in a composition (-12780), so a take with a real voice can't be made in it. Opt-in: `TEST_RUNNER_CUE_LOUDNESS_DIR`
    /// names the folder the sounds go to; `tools/audio/loudness_report.py` measures them (integrated loudness BS.1770 and true peak).
    @MainActor
    @Suite(
        "Loudness report", .serialized, .timeLimit(.minutes(10)),
        .enabled(if: ProcessInfo.processInfo.environment["CUE_LOUDNESS_DIR"] != nil)
    )
    struct LoudnessReportExportTests {
        nonisolated private static let readings = ["human-pt-BR-1", "human-pt-BR-2", "human-en-US-1", "human-en-US-2"]

        @Test(arguments: readings)
        func exportsForMeasuring(reading: String) async throws {
            let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_LOUDNESS_DIR"]))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let bundle = Bundle(for: LoudnessBundleToken.self)
            let track = try #require(CueTrack.allCases.first?.bundledFile, "no library track in the app")
            let trackName = try Self.stored(track)
            defer { EditMediaFiles.remove([trackName]) }
            let trackLength: Double
            do { trackLength = try await AVURLAsset(url: track).load(.duration).seconds } catch {
                Issue.record("library track \(track.lastPathComponent): \(error)")
                throw error
            }
            let voice = try #require(bundle.url(forResource: reading, withExtension: "m4a"), "\(reading) is missing")
            let seconds = try await AVURLAsset(url: voice).load(.duration).seconds
            let voiceName = try Self.stored(voice)
            let take = try await TestClip.make(seconds: Int(seconds.rounded(.up)) + 1, loudSeconds: [])
            defer {
                try? FileManager.default.removeItem(at: take)
                EditMediaFiles.remove([voiceName])
            }
            var edit = TakeEdit(sourceDuration: Double(Int(seconds.rounded(.up)) + 1), aspect: .portrait)
            edit.voiceOvers = [VoiceOverClip(fileName: voiceName, duration: seconds, anchor: 0)]
            try await Self.export(edit, of: take, to: folder, named: "\(reading)-narration")
            var music = MusicClip(fileName: trackName, title: "Library", fileDuration: trackLength, start: 0, length: min(seconds, trackLength))
            music.volume = MusicDefaults.standardVolume
            music.duck = .standard
            edit.music = [music]
            try await Self.export(edit, of: take, to: folder, named: "\(reading)-narration-music")
            edit.voiceOvers = []
            try await Self.export(edit, of: take, to: folder, named: "\(reading)-music-alone")
        }

        private static func stored(_ url: URL) throws -> String {
            let file = try EditMediaFiles.newFile(pathExtension: url.pathExtension)
            try FileManager.default.copyItem(at: url, to: file.url)
            return file.name
        }

        /// The exported video, as `name`.mov in `folder`.
        private static func export(_ edit: TakeEdit, of take: URL, to folder: URL, named name: String) async throws {
            let output: URL
            do {
                output = try await VideoExportService().export(videoAt: take, options: ExportOptions(aspect: .portrait, edit: edit))
            } catch {
                Issue.record("exporting \(name): \(error)")
                throw error
            }
            // The file as a creator gets it; the report decodes its AAC.
            let destination = folder.appending(path: "\(name).mov")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: output, to: destination)
        }
    }
}
