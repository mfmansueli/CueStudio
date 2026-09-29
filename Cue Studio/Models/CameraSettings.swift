//
//  CameraSettings.swift
//  Cue Studio
//

import Foundation

/// Capture and take options. Stored as the creator's defaults (`PreferencesService`); the recording
/// screen works on a copy for the session (`SessionSetupService`), so a platform recommendation or a
/// change for one take never rewrites them. `CreatorSetup` names the fields Creator Setup owns.
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
    /// Name of that input when it was picked, to say which mic is missing when it isn't connected.
    /// Optional, like every field added later: settings saved without it still decode.
    var microphoneName: String?
    var countdown: Countdown = .three
    var scrollsWithRecording: Bool = true
    var stopsWhenScriptEnds: Bool = true
    var codec: VideoCodec = .hevc
}
