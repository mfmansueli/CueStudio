//
//  MotionAnalysisDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import Darwin
import Foundation
import os
import Testing
@testable import Cue_Studio

/// The motion analysis on this iPhone, on COPIES of the newest takes in its library (never the takes themselves): how long it
/// takes per frame and against the video's length at the priority the app runs it, how much memory it holds, how warm the
/// iPhone gets, how many moments have a face, and how much the camera moved (measured beside the people). Printed as `MOTION …`.
///
/// Opt-in and on a device: `CUE_DEVICE="<iPhone>" scripts/test.sh device MotionAnalysisDeviceTests`.
@Suite(
    "Motion analysis on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_MOTION_E2E"] != nil),
    .timeLimit(.minutes(5))
)
struct MotionAnalysisDeviceTests {
    @Test func analyzesTheNewestTakes() async throws {
        await KeepScreenAwake.enable()
        let takes = Self.newestTakes(2)
        try #require(!takes.isEmpty, "No takes on this iPhone")
        for original in takes {
            let copy = URL.temporaryDirectory.appending(path: "motion-\(UUID().uuidString).\(original.pathExtension)")
            try FileManager.default.copyItem(at: original, to: copy)
            defer { try? FileManager.default.removeItem(at: copy) }
            let asset = AVURLAsset(url: copy)
            let duration = try await asset.load(.duration).seconds
            let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
            let (size, rate) = try await track.load(.naturalSize, .nominalFrameRate)
            let peak = OSAllocatedUnfairLock(initialState: Self.footprint())
            let base = Self.footprint()
            let watching = Task.detached {
                while !Task.isCancelled {
                    let now = Self.footprint()
                    peak.withLock { $0 = max($0, now) }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            let heatBefore = ProcessInfo.processInfo.thermalState
            let started = ContinuousClock.now
            // At the priority the app analyzes with.
            let analysis = try await Task.detached(priority: .utility) {
                try await MotionAnalyzer().analyze(videoAt: copy, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
            }.value
            let took = (ContinuousClock.now - started) / .seconds(1)
            watching.cancel()
            let withFace = analysis.subjects.filter { !$0.faces.isEmpty }.count
            let withBody = analysis.subjects.filter { !$0.bodies.isEmpty }.count
            let shake = analysis.shifts.map { hypot($0.dx * analysis.width, $0.dy * analysis.height) }
            let meanShake = shake.reduce(0, +) / Double(max(1, shake.count))
            let meanTurn = analysis.shifts.map { abs($0.angle) }.reduce(0, +) / Double(max(1, analysis.shifts.count))
            let data = try JSONEncoder().encode(analysis)
            print(
                "MOTION \(original.lastPathComponent) · \(Int(size.width))×\(Int(size.height)) \(Int(rate)) fps · \(String(format: "%.1f", duration)) s"
                    + " · analysis \(String(format: "%.1f", took)) s (\(String(format: "%.2f", took / duration))× its length,"
                    + " \(String(format: "%.1f", took * 1000 / Double(max(1, analysis.shifts.count)))) ms a frame)"
                    + " · memory +\((peak.withLock { $0 } - base) / 1_000_000) MB · heat \(Self.name(heatBefore)) → \(Self.name(ProcessInfo.processInfo.thermalState))"
                    + " · faces in \(withFace)/\(analysis.subjects.count) · bodies in \(withBody)/\(analysis.subjects.count)"
                    + " · mean shift \(String(format: "%.2f", meanShake)) px, turn \(String(format: "%.4f", meanTurn)) rad · file \(data.count / 1000) KB"
            )
            #expect(analysis.isComplete)
        }
    }

    // MARK: - Helpers

    static func newestTakes(_ count: Int) -> [URL] {
        let folder = URL.applicationSupportDirectory.appending(path: "Takes", directoryHint: .isDirectory)
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles
        )) ?? []).filter { ["mov", "mp4"].contains($0.pathExtension.lowercased()) }
        return Array(files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }.prefix(count))
    }

    static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    static func name(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
