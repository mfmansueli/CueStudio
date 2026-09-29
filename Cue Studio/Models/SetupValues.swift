//
//  SetupValues.swift
//  Cue Studio
//

import Foundation

/// Some of the Creator Setup's values: what a platform recommends, or what the creator changed for
/// one take. A nil field leaves the value underneath as it is.
nonisolated struct SetupValues: Hashable, Sendable {
    var lens: CameraLens?
    var microphone: MicrophoneChoice?
    var resolution: VideoResolution?
    var frameRate: FrameRate?
    var aspect: AspectRatio?
    var textSize: Double?
    var speed: Double?
    var readingLine: ReadingLinePlacement?
    var isMirrored: Bool?
    var showsSafeZones: Bool?

    /// The fields this sets.
    var fields: Set<SetupField> {
        var fields: Set<SetupField> = []
        if lens != nil { fields.insert(.camera) }
        if microphone != nil { fields.insert(.microphone) }
        if resolution != nil { fields.insert(.quality) }
        if frameRate != nil { fields.insert(.frameRate) }
        if aspect != nil { fields.insert(.format) }
        if textSize != nil { fields.insert(.textSize) }
        if speed != nil { fields.insert(.speed) }
        if readingLine != nil { fields.insert(.readingLine) }
        if isMirrored != nil { fields.insert(.mirror) }
        if showsSafeZones != nil { fields.insert(.safeZones) }
        return fields
    }

    var isEmpty: Bool { fields.isEmpty }

    /// `setup` with these values on top.
    func applied(to setup: CreatorSetup) -> CreatorSetup {
        var setup = setup
        if let lens { setup.lens = lens }
        if let microphone { setup.microphone = microphone }
        if let resolution { setup.resolution = resolution }
        if let frameRate { setup.frameRate = frameRate }
        if let aspect { setup.aspect = aspect }
        if let textSize { setup.textSize = textSize }
        if let speed { setup.speed = speed }
        if let readingLine { setup.readingLine = readingLine }
        if let isMirrored { setup.isMirrored = isMirrored }
        if let showsSafeZones { setup.showsSafeZones = showsSafeZones }
        return setup
    }

    /// The fields whose value here is not the one `setup` has.
    func differences(from setup: CreatorSetup) -> Set<SetupField> {
        applied(to: setup).fields(differingFrom: setup)
    }

    /// Keeps whatever changed between `old` and `new` (a change made while recording).
    mutating func record(from old: CreatorSetup, to new: CreatorSetup) {
        for field in new.fields(differingFrom: old) {
            take(field, from: new)
        }
    }

    /// Drops values that `setup` already has, so only real differences remain.
    mutating func removeMatching(_ setup: CreatorSetup) {
        clear(fields.subtracting(differences(from: setup)))
    }

    mutating func clear(_ fields: Set<SetupField>) {
        for field in fields {
            switch field {
            case .camera: lens = nil
            case .microphone: microphone = nil
            case .quality: resolution = nil
            case .frameRate: frameRate = nil
            case .format: aspect = nil
            case .textSize: textSize = nil
            case .speed: speed = nil
            case .readingLine: readingLine = nil
            case .mirror: isMirrored = nil
            case .safeZones: showsSafeZones = nil
            }
        }
    }

    private mutating func take(_ field: SetupField, from setup: CreatorSetup) {
        switch field {
        case .camera: lens = setup.lens
        case .microphone: microphone = setup.microphone
        case .quality: resolution = setup.resolution
        case .frameRate: frameRate = setup.frameRate
        case .format: aspect = setup.aspect
        case .textSize: textSize = setup.textSize
        case .speed: speed = setup.speed
        case .readingLine: readingLine = setup.readingLine
        case .mirror: isMirrored = setup.isMirrored
        case .safeZones: showsSafeZones = setup.showsSafeZones
        }
    }
}
