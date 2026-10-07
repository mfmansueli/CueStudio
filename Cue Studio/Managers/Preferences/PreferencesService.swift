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

    /// The creator's own cues, on the script page's cues bar after the board's four (oldest first).
    var customCues: [String] {
        didSet { defaults.set(customCues, forKey: DefaultsKey.customCues) }
    }

    /// The script page's Cues switch: whether the page draws the cue tags (on until the creator turns it off). The teleprompter has
    /// its own (`PrompterSettings.showsCues`).
    var showsCuesOnPage: Bool {
        didSet { defaults.set(showsCuesOnPage, forKey: DefaultsKey.showsCuesOnPage) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prompter = Self.load(PrompterSettings.self, key: DefaultsKey.prompterSettings, from: defaults) ?? PrompterSettings()
        camera = Self.load(CameraSettings.self, key: DefaultsKey.cameraSettings, from: defaults) ?? CameraSettings()
        customCues = defaults.stringArray(forKey: DefaultsKey.customCues) ?? []
        showsCuesOnPage = defaults.object(forKey: DefaultsKey.showsCuesOnPage) as? Bool ?? true
        // The reading line's first-time tip and the old full script editor are gone; so is what they left behind.
        defaults.removeObject(forKey: DefaultsKey.legacyReadingLineTipSeen)
        defaults.removeObject(forKey: DefaultsKey.legacyScriptEditorTextSize)
        resetLowReadingLineOnce()
    }

    /// A line farther than this below the lens (about a third of the screen) puts the text box in the middle of it, not near the top.
    static let lowestUsualLineOffset: Double = 260

    /// Once, in v30: a reading line saved lower than that (from the old Settings slider) is cleared, so the box opens near the top
    /// again, where Cue recommends. From then on the prompter remembers whatever the creator sets (`SessionSetupService.rememberReadingLayout`).
    private func resetLowReadingLineOnce() {
        guard !defaults.bool(forKey: DefaultsKey.readingLineResetV30) else { return }
        defaults.set(true, forKey: DefaultsKey.readingLineResetV30)
        guard let offset = prompter.readingLineOffset, offset > Self.lowestUsualLineOffset else { return }
        prompter.readingLineOffset = nil
        store(prompter, key: DefaultsKey.prompterSettings)
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

    /// "Reset Creator Setup": recording and reading defaults. Scripts, takes, edits and the
    /// other camera options stay.
    func resetCreatorSetup() {
        creatorSetup = CreatorSetup()
        resetPrompter()
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
