//
//  PreferencesService.swift
//  Cue Studio
//

import Foundation

/// Prompter and camera settings, kept between sessions.
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
