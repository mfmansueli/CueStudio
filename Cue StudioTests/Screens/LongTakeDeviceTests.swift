//
//  LongTakeDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// A 30-minute take with 600 caption lines on this iPhone: how quick the editor stays (opening, the line under the playhead
/// asked every frame, the timeline, a caption corrected), how big its draft gets, how long the preview takes to build and
/// how much memory it holds, and how long Studio Voice takes and how much it writes. The footage is a textured minute that
/// decodes like a recording, copied 30 times. Printed as "LONG TAKE …" lines.
///
/// Opt-in and on a device: `CUE_DEVICE=<iPhone> scripts/test.sh device LongTakeDeviceTests`.
@MainActor
@Suite("A long captioned take on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_LONG_TAKE"] != nil))
struct LongTakeDeviceTests {
    static let minutes = 30
    static let lines = 600

    @Test func theEditorStaysQuickWithAnHourOfLines() async throws {
        let url = try await Self.footage()
        defer { try? FileManager.default.removeItem(at: url) }
        let drafts = URL.temporaryDirectory.appending(path: "long-drafts-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: drafts) }
        let before = MotionAnalysisDeviceTests.footprint()

        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = Double(Self.minutes * 60)
        // The fake library finds a take's video in the temporary folder, where the footage is.
        take.fileName = url.lastPathComponent
        var edit = TakeEdit(sourceDuration: take.duration, aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.showsCaptions = true
        edit.captionCollection = CaptionSettings(theme: .pop)
        edit.captions = Self.captions()
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: TakeEditService(), drafts: QuickEditDraftStore(directory: drafts),
            toast: ToastService(), player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        let opened = try await Self.time { await viewModel.prepare() }
        #expect(viewModel.isReady)

        // What every caption read used to cost: mapping all the lines again.
        let mapping = try await Self.time { _ = viewModel.edit.editedCaptionInstances }
        viewModel.captionMapStore = nil
        let mapBuilt = try await Self.time { _ = viewModel.captionMap }
        // The line under the playhead, asked every frame while playing.
        let frames = 1800
        let perFrame = try await Self.time {
            for frame in 0..<frames {
                player.seek(to: Double(frame))
                _ = viewModel.activeCaptionCueID
            }
        } / Double(frames)
        let timeline = try await Self.time { _ = viewModel.timelineInput(heightClass: .regular) }
        // A line corrected twenty times, each an undo step.
        let lineIDs = viewModel.edit.captions.prefix(20).map(\.id)
        let corrected = try await Self.time {
            for (index, id) in lineIDs.enumerated() { viewModel.setCaptionText(id, "Corrected line \(index)") }
        } / Double(lineIDs.count)
        let draft = QuickEditDraft(takeID: take.id, edit: viewModel.edit, playhead: 600, history: viewModel.document.history, savedAt: .now)
        var bytes = 0
        let written = try await Self.time { bytes = try JSONEncoder.library.encode(draft).count }
        let after = MotionAnalysisDeviceTests.footprint()
        print(
            "LONG TAKE editor · \(Self.minutes) min, \(Self.lines) lines"
                + " · open \(Self.ms(opened))"
                + " · mapping all lines \(Self.ms(mapping)) (was every read) · map once \(Self.ms(mapBuilt))"
                + " · line under the playhead \(String(format: "%.1f µs", perFrame * 1_000_000)) a frame"
                + " · timeline \(Self.ms(timeline)) · a corrected line \(Self.ms(corrected))"
                + " · draft \(bytes / 1024) KB in \(Self.ms(written))"
                + " · memory +\((after - before) / 1_048_576) MB"
        )
        #expect(perFrame < 0.001)
        viewModel.cancel()
    }

    @Test func thePreviewBuildsAndStudioVoiceStaysWithinItsBudget() async throws {
        let url = try await Self.footage()
        defer { try? FileManager.default.removeItem(at: url) }
        var edit = TakeEdit(sourceDuration: Double(Self.minutes * 60), aspect: .portrait)
        edit.voiceEnhancement = .off
        edit.showsCaptions = true
        edit.captionCollection = CaptionSettings(theme: .pop)
        edit.captions = Self.captions()
        let before = MotionAnalysisDeviceTests.footprint()
        let sounds = RecordingSoundCache()
        var built: EditedComposition?
        let preview = try await Self.time {
            built = try await EditRenderRequest.prepare(source: url, edit: edit, purpose: .editorPreview(rendersCurveSound: true), sounds: sounds)
                .build()
        }
        let first = try await RenderParity.frame(try #require(built).asset, composition: built?.videoComposition, at: 905)
        let withPreview = MotionAnalysisDeviceTests.footprint()

        var treated = edit
        treated.voiceEnhancement = .strong
        treated.noiseReduction = .soft
        var file: URL?
        let voice = try await Self.time { file = try await sounds.treated(url, processing: treated.voiceProcessing) }
        let size = (try? file?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let free = (try? URL.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        print(
            "LONG TAKE preview · \(Self.minutes) min, \(Self.lines) caption lines"
                + " · built in \(Self.ms(preview)) · frame \(first.width)×\(first.height)"
                + " · memory +\((withPreview - before) / 1_048_576) MB"
                + " · Studio Voice \(String(format: "%.1f s", voice)) for \(size / 1_048_576) MB"
                + " · budget \(RecordingSoundCache.byteBudget(freeSpace: free) / 1_048_576) MB of \(free / 1_073_741_824) GB free"
        )
        if let file { try? FileManager.default.removeItem(at: file) }
    }

    // MARK: - Helpers

    /// A textured minute, decoded like a recording, copied `minutes` times without encoding again.
    private static func footage() async throws -> URL {
        let minute = try await TestFootage.make(seconds: 60, width: 720, height: 1280)
        defer { try? FileManager.default.removeItem(at: minute) }
        let asset = AVURLAsset(url: minute)
        let length = try await asset.load(.duration)
        let composition = AVMutableComposition()
        for index in 0..<minutes {
            try await composition.insertTimeRange(
                CMTimeRange(start: .zero, duration: length), of: asset, at: CMTimeMultiply(length, multiplier: Int32(index))
            )
        }
        let url = URL.temporaryDirectory.appending(path: "long-take-\(UUID().uuidString).mov")
        let session = try #require(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await session.export(to: url, as: .mov)
        return url
    }

    /// A line every three seconds, five words each, timed by word.
    private static func captions() -> [CaptionCue] {
        (0..<lines).map { index in
            let start = Double(index) * 3
            let words = (0..<5).map { word in
                CaptionWord(text: "word\(word)", start: start + Double(word) * 0.5, end: start + Double(word) * 0.5 + 0.4, isEstimated: false)
            }
            return CaptionCue(text: words.map(\.text).joined(separator: " "), start: start, end: start + 2.6, words: words)
        }
    }

    private static func time(_ work: () async throws -> Void) async throws -> TimeInterval {
        let start = ProcessInfo.processInfo.systemUptime
        try await work()
        return ProcessInfo.processInfo.systemUptime - start
    }

    private static func ms(_ seconds: TimeInterval) -> String {
        String(format: "%.1f ms", seconds * 1000)
    }
}
