//
//  CreatorSetup.swift
//  Cue Studio
//

import Foundation

/// The Creator Setup: how the creator usually records ("This is what you usually use"). It is a
/// view over the fields of `CameraSettings` and `PrompterSettings` it owns, so capture, the
/// prompter, takes and export keep reading the settings they always did, and there is one place
/// that stores each value.
///
/// Three layers decide what a recording uses (see `SessionSetup`): a change for this take, then a
/// platform recommendation the creator accepted, then this setup. A recommendation never writes
/// here.
nonisolated struct CreatorSetup: Hashable, Sendable {
    var lens: CameraLens
    var microphone: MicrophoneChoice
    var resolution: VideoResolution
    var frameRate: FrameRate
    var aspect: AspectRatio
    /// Selfie text size in points.
    var textSize: Double
    /// Default scroll speed (1.0× = 215 words a minute).
    var speed: Double
    var readingLine: ReadingLinePlacement
    var isMirrored: Bool
    var showsSafeZones: Bool

    /// Cue's defaults when nothing is passed: front camera, automatic mic, 1080p30, 9:16.
    init(camera: CameraSettings = CameraSettings(), prompter: PrompterSettings = PrompterSettings()) {
        lens = camera.lens
        microphone = MicrophoneChoice(id: camera.microphoneID, name: camera.microphoneName)
        resolution = camera.resolution
        frameRate = camera.frameRate
        aspect = camera.aspect
        showsSafeZones = camera.showsSafeZones
        textSize = prompter.size
        speed = prompter.speed
        readingLine = ReadingLinePlacement(offset: prompter.readingLineOffset)
        isMirrored = prompter.isMirrored
    }

    // MARK: - Settings

    /// `camera` with this setup's fields; everything else (grid, countdown, codec…) as it was.
    func applied(to camera: CameraSettings) -> CameraSettings {
        var camera = camera
        camera.lens = lens
        camera.microphoneID = microphone.id
        camera.microphoneName = microphone.name
        camera.resolution = resolution
        camera.frameRate = frameRate
        camera.aspect = aspect
        camera.showsSafeZones = showsSafeZones
        return camera
    }

    /// `prompter` with this setup's fields; font, colors, window and the rest as they were.
    func applied(to prompter: PrompterSettings) -> PrompterSettings {
        var prompter = prompter
        prompter.size = textSize
        prompter.speed = speed
        prompter.readingLineOffset = readingLine.offset
        prompter.isMirrored = isMirrored
        return prompter
    }

    /// Takes the setup's fields from `camera`.
    mutating func update(from camera: CameraSettings) {
        lens = camera.lens
        microphone = MicrophoneChoice(id: camera.microphoneID, name: camera.microphoneName)
        resolution = camera.resolution
        frameRate = camera.frameRate
        aspect = camera.aspect
        showsSafeZones = camera.showsSafeZones
    }

    /// Takes the setup's fields from `prompter`.
    mutating func update(from prompter: PrompterSettings) {
        textSize = prompter.size
        speed = prompter.speed
        readingLine = ReadingLinePlacement(offset: prompter.readingLineOffset)
        isMirrored = prompter.isMirrored
    }

    // MARK: - Comparing

    /// The fields where `other` has another value.
    func fields(differingFrom other: CreatorSetup) -> Set<SetupField> {
        Set(SetupField.allCases.filter { !hasSameValue(as: other, for: $0) })
    }

    private func hasSameValue(as other: CreatorSetup, for field: SetupField) -> Bool {
        switch field {
        case .camera: lens == other.lens
        case .microphone: microphone == other.microphone
        case .format: aspect == other.aspect
        case .quality: resolution == other.resolution
        case .frameRate: frameRate == other.frameRate
        case .textSize: textSize == other.textSize
        case .speed: speed == other.speed
        case .readingLine: readingLine == other.readingLine
        case .mirror: isMirrored == other.isMirrored
        case .safeZones: showsSafeZones == other.showsSafeZones
        }
    }

    // MARK: - Labels

    /// How a field reads on screen: "Front", "4K", "30 fps", "9:16", "Large · 36 pt".
    func label(for field: SetupField) -> String {
        switch field {
        case .camera:
            return lens.isFront ? String(localized: "Front") : String(localized: "Back")
        case .microphone:
            return microphone.label
        case .format:
            return aspect.label
        case .quality:
            return resolution.label
        case .frameRate:
            return String(localized: "\(frameRate.rawValue) fps")
        case .textSize:
            let points = Int(textSize.rounded())
            guard let preset = PrompterTextSize(points: textSize) else { return String(localized: "\(points) pt") }
            return String(localized: "\(preset.label) · \(points) pt")
        case .speed:
            return speed.formatted(.number.precision(.fractionLength(1)).locale(.interface)) + "×"
        case .readingLine:
            guard let offset = readingLine.offset else { return String(localized: "Recommended") }
            return String(localized: "\(Int(offset)) pt below the camera")
        case .mirror:
            return isMirrored ? String(localized: "On") : String(localized: "Off")
        case .safeZones:
            return showsSafeZones ? String(localized: "On") : String(localized: "Off")
        }
    }

    /// The fields' labels in reading order: "9:16 · 4K · 30 fps".
    func summary(of fields: Set<SetupField>) -> String {
        SetupField.allCases.filter(fields.contains).map { label(for: $0) }.joined(separator: " · ")
    }

    /// What the recording screen shows: "4K · 9:16".
    var captureSummary: String {
        "\(resolution.label) · \(aspect.label)"
    }
}
