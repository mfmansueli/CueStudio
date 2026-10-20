//
//  EyeContactAnalysisTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The analysis kept next to a recording: packed frames that read back the same, stretches analyzed in any order, and never used
/// for another file under the same name.
@Suite("EyeContactAnalysis")
struct EyeContactAnalysisTests {
    @Test func framesReadBackAsTheyWereWritten() throws {
        var sharp = EyeTestData.face()
        sharp.sharpness = 42
        let samples = [
            EyeSample(time: 0, face: sharp),
            EyeSample(time: 1.0 / 30, face: nil),
            EyeSample(time: 2.0 / 30, face: EyeTestData.face(opening: 0.05, crowded: true)),
        ]
        let read = try EyeSamplePacking.unpack(EyeSamplePacking.pack(samples))
        #expect(read.count == 3)
        #expect(read[1].face == nil)
        #expect(read[2].face?.crowded == true)
        for (written, back) in zip(samples, read) {
            #expect(written.time == back.time)
            guard let a = written.face, let b = back.face else { continue }
            #expect(abs(a.confidence - b.confidence) < 0.000_1)
            #expect(abs(a.sharpness - b.sharpness) < 0.001)
            for (eyeA, eyeB) in zip(a.eyes, b.eyes) {
                #expect(eyeB.isComplete)
                #expect(abs(eyeA.irisRadius - eyeB.irisRadius) < 0.000_001)
                for (pointA, pointB) in zip(eyeA.contour + [eyeA.iris], eyeB.contour + [eyeB.iris]) {
                    #expect(abs(pointA.x - pointB.x) < 0.000_001 && abs(pointA.y - pointB.y) < 0.000_001)
                }
            }
        }
        #expect(EyeSamplePacking.pack(samples).count == 3 * EyeSamplePacking.recordSize)
    }

    @Test func aDamagedBlockIsRefused() {
        #expect(throws: EyeSamplePacking.PackingError.self) { try EyeSamplePacking.unpack(Data([1, 2, 3])) }
    }

    @Test func stretchesAddUpInAnyOrder() {
        var analysis = EyeContactAnalysis(duration: 10, width: 1080, height: 1920, fileStamp: "a")
        analysis.frameRate = 30
        func frames(_ span: TimeSpan) -> [EyeSample] {
            stride(from: (span.start * 30).rounded(.up), to: span.end * 30, by: 1).map { EyeSample(time: $0 / 30, face: nil) }
        }
        analysis.add(frames(TimeSpan(start: 4, end: 7)), over: TimeSpan(start: 4, end: 7))
        #expect(!analysis.isComplete)
        #expect(analysis.covers(TimeSpan(start: 4.5, end: 6.5)))
        #expect(!analysis.covers(TimeSpan(start: 3, end: 5)))
        #expect(analysis.missing(in: TimeSpan(start: 0, end: 10)) == [TimeSpan(start: 0, end: 4), TimeSpan(start: 7, end: 10)])
        #expect(abs(analysis.progress - 0.3) < 0.000_1)
        analysis.add(frames(TimeSpan(start: 7, end: 10)), over: TimeSpan(start: 7, end: 10))
        analysis.add(frames(TimeSpan(start: 0, end: 4)), over: TimeSpan(start: 0, end: 4))
        #expect(analysis.isComplete)
        #expect(analysis.samples.count == 300)
        #expect(analysis.samples.map(\.time) == analysis.samples.map(\.time).sorted())
    }

    @Test func itIsKeptForItsOwnFileOnly() throws {
        let analysis = EyeTestData.analysis(fileStamp: "100@5")
        #expect(analysis.isCurrent(forFile: "100@5"))
        #expect(!analysis.isCurrent(forFile: "101@5"))
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let read = try PropertyListDecoder().decode(EyeContactAnalysis.self, from: encoder.encode(analysis))
        #expect(read.samples.count == analysis.samples.count)
        #expect(read.analyzed == analysis.analyzed)
    }

    @Test func theStoreForgetsAnAnalysisOfAReplacedRecording() throws {
        let recording = URL.temporaryDirectory.appending(path: "eyes-\(UUID().uuidString).mov")
        try Data([0, 1, 2]).write(to: recording)
        defer {
            EyeContactAnalysisStore.remove(forRecording: recording)
            try? FileManager.default.removeItem(at: recording)
        }
        EyeContactAnalysisStore.save(EyeTestData.analysis(fileStamp: EyeContactAnalysisStore.fileStamp(of: recording)), forRecording: recording)
        #expect(EyeContactAnalysisStore.load(forRecording: recording)?.isComplete == true)
        #expect(EyeContactAnalysisStore.plan(forRecording: recording) != nil)
        // Another file under the same name: the old analysis is never used.
        try Data(repeating: 7, count: 64).write(to: recording)
        #expect(EyeContactAnalysisStore.load(forRecording: recording) == nil)
        #expect(EyeContactAnalysisStore.plan(forRecording: recording) == nil)
    }

    @Test func aCacheThatGoesIsMadeAgainNotMissed() throws {
        let recording = URL.temporaryDirectory.appending(path: "eyes-\(UUID().uuidString).mov")
        try Data([0]).write(to: recording)
        defer { try? FileManager.default.removeItem(at: recording) }
        EyeContactAnalysisStore.save(EyeTestData.analysis(fileStamp: EyeContactAnalysisStore.fileStamp(of: recording)), forRecording: recording)
        try FileManager.default.removeItem(at: EyeContactAnalysisStore.url(forRecording: recording))
        #expect(EyeContactAnalysisStore.load(forRecording: recording) == nil)
    }
}
