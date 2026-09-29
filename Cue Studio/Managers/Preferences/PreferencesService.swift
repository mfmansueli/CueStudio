//
//  PreferencesService.swift
//  Cue Studio
//

import Foundation

/// Prompter and camera settings, kept between sessions. These are the creator's defaults: the
/// Creator Setup (`creatorSetup`) plus how the prompter looks. A recording session reads them
/// through `SessionSetupService`, which never writes a recommendation or a one-take change back.
@MainActor
@Observable
final class PreferencesService {
    var prompter: PrompterSettings {
        didSet { store(prompter, key: DefaultsKey.prompterSettings) }
    }

    var camera: CameraSettings {
        didSet { store(camera, key: DefaultsKey.cameraSettings) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prompter = Self.load(PrompterSettings.self, key: DefaultsKey.prompterSettings, from: defaults) ?? PrompterSettings()
        camera = Self.load(CameraSettings.self, key: DefaultsKey.cameraSettings, from: defaults) ?? CameraSettings()
        // The reading line's first-time tip is gone; so is the flag it left behind.
        defaults.removeObject(forKey: DefaultsKey.legacyReadingLineTipSeen)
    }

    // MARK: - Creator Setup

    /// How the creator usually records: camera, microphone, quality, format and the teleprompter
    /// defaults. Stored inside `camera` and `prompter`, so there is one copy of each value.
    var creatorSetup: CreatorSetup {
        get { CreatorSetup(camera: camera, prompter: prompter) }
        set {
            let camera = newValue.applied(to: self.camera)
            if camera != self.camera { self.camera = camera }
            let prompter = newValue.applied(to: self.prompter)
            if prompter != self.prompter { self.prompter = prompter }
        }
    }

    /// "Reset Creator Setup": Cue's defaults for the setup only. Scripts, takes, edits, the
    /// prompter's look and the rest of the camera options stay.
    func resetCreatorSetup() {
        creatorSetup = CreatorSetup()
    }

    func resetPrompter() {
        prompter = PrompterSettings()
    }

    // MARK: - Storage

    private func store<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// A settings blob from an older build that no longer decodes falls back to the defaults.
    private static func load<Value: Decodable>(_ type: Value.Type, key: String, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
