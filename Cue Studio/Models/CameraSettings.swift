//
//  CameraSettings.swift
//  Cue Studio
//

import Foundation

/// Capture and take options. Destination presets overwrite frame, resolution and frame rate when
/// a script opens in the camera; everything else is the creator's.
nonisolated struct CameraSettings: Codable, Hashable, Sendable {
    var lens: CameraLens = .front
    var resolution: VideoResolution = .hd1080
    var frameRate: FrameRate = .fps30
    var aspect: AspectRatio = .portrait
    var showsGrid: Bool = false
    var showsSafeZones: Bool = true
    var stabilization: Bool = true
    /// UID of the preferred audio input; nil uses the system default.
    var microphoneID: String?
    var countdown: Countdown = .three
    var scrollsWithRecording: Bool = true
    var stopsWhenScriptEnds: Bool = true
    var codec: VideoCodec = .hevc

    mutating func apply(_ preset: PlatformPreset) {
        aspect = preset.aspect
        resolution = preset.resolution
        frameRate = preset.frameRate
    }
}
