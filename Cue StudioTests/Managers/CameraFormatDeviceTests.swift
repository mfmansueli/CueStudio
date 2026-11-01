//
//  CameraFormatDeviceTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// A10 on a real camera: a take asked in 4K at 60 fps says the format the camera really recorded (the front camera of some iPhones has no
/// 4K at 60), checked against the recorded file itself. Each clip is deleted at once (a `take-*.mov` left in the temporary folder would come
/// back as a take, `TakeRecovery`). Opt-in, on a device: `CUE_DEVICE=… scripts/test.sh device CameraFormatDeviceTests`.
@MainActor
@Suite("Camera format on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_CAMERA_FORMAT"] != nil))
struct CameraFormatDeviceTests {
    @Test(arguments: [CameraLens.front, .wide])
    func aTakeSaysTheFormatTheCameraReallyRecorded(_ lens: CameraLens) async throws {
        let camera = CameraManager()
        var asked = CameraSettings()
        asked.lens = lens
        asked.resolution = .uhd4K
        asked.frameRate = .fps60
        await camera.start(with: asked)
        defer { Task { await camera.stop() } }
        try #require(camera.status == .running, "The camera didn't start: \(camera.status)")
        try await Task.sleep(for: .seconds(1))
        try await camera.startRecording()
        try await Task.sleep(for: .seconds(2))
        let clip = try #require(await camera.stopRecording())
        defer { try? FileManager.default.removeItem(at: clip.url) }

        let track = try #require(try await AVURLAsset(url: clip.url).loadTracks(withMediaType: .video).first)
        let (size, fps) = try await track.load(.naturalSize, .nominalFrameRate)
        let file = (VideoResolution.nearest(shortSide: min(size.width, size.height)), FrameRate.nearest(to: Double(fps)))
        print("CAMERA FORMAT · \(lens) · asked 4K/60 · take says \(clip.resolution?.label ?? "?")/\(clip.frameRate?.rawValue ?? 0) · file \(Int(size.width))×\(Int(size.height)) at \(fps) fps")
        #expect(clip.resolution == file.0)
        #expect(clip.frameRate == file.1)
    }
}
