//
//  LanguageService.swift
//  Cue Studio
//

import Foundation

/// The three languages Cue keeps apart (Settings › Language & Region):
/// - the **app language**, what Cue's interface is in;
/// - the **Voice Following language**, what Cue listens for while the creator reads;
/// - the **script language**, what new scripts are written in (each script keeps its own).
///
/// Changing one never changes another, never translates a script and never touches the iPhone's
/// language. An iPhone in Italian can run Cue in English for a script in Portuguese read aloud in
/// Portuguese.
@MainActor
@Observable
final class LanguageService {
    /// What the creator picked for the interface; nil follows the iPhone.
    private(set) var appLanguage: CueLanguage?
    /// What the interface shows now: `appLanguage`, else the iPhone's language when Cue is
    /// translated into it, else English.
    private(set) var interfaceLanguage: CueLanguage

    /// Nil listens in each script's language.
    var voiceFollowingLanguage: CueLanguage? {
        didSet { save(voiceFollowingLanguage, key: DefaultsKey.voiceFollowingLanguage) }
    }

    /// The language new scripts start in; nil detects it from what's written.
    var scriptLanguage: CueLanguage? {
        didSet { save(scriptLanguage, key: DefaultsKey.scriptLanguage) }
    }

    private let defaults: UserDefaults
    private let store: AppLanguageStoring
    private let apply: (CueLanguage) -> Void

    /// - Parameter apply: makes `interfaceLanguage` the running app's (see `AppServices`). Unit
    ///   tests leave it out, so they never change the language other tests read strings in.
    init(defaults: UserDefaults = .standard, store: AppLanguageStoring, apply: @escaping (CueLanguage) -> Void = { _ in }) {
        self.defaults = defaults
        self.store = store
        self.apply = apply
        let chosen = store.chosenLocalization.flatMap(CueLanguage.matching(interfaceLocalization:))
        let interface = Self.interfaceLanguage(chosen: chosen, store: store)
        appLanguage = chosen
        interfaceLanguage = interface
        voiceFollowingLanguage = Self.load(key: DefaultsKey.voiceFollowingLanguage, from: defaults)
        scriptLanguage = Self.load(key: DefaultsKey.scriptLanguage, from: defaults)
        apply(interface)
    }

    // MARK: - App language

    /// The locale SwiftUI and `String(localized:)` resolve the interface in.
    var interfaceLocale: Locale { Locale(identifier: interfaceLanguage.interfaceLocalization) }

    /// Switches the interface now and at every later launch. Nothing else changes.
    func setAppLanguage(_ language: CueLanguage?) {
        guard language != appLanguage else { return }
        store.chosenLocalization = language?.interfaceLocalization
        appLanguage = language
        let interface = Self.interfaceLanguage(chosen: language, store: store)
        guard interface != interfaceLanguage else { return }
        interfaceLanguage = interface
        apply(interface)
    }

    /// What "iPhone Language" shows in: the iPhone's language when Cue has it, else English.
    var systemInterfaceLanguage: CueLanguage {
        CueLanguage.matching(interfaceLocalization: store.systemLocalization) ?? .english
    }

    // MARK: - Voice Following

    /// What Voice Following listens for with `script`. The interface language never takes part.
    func speechRequest(for script: Script?) -> SpeechLanguageRequest {
        SpeechLanguageRequest(
            voiceFollowing: voiceFollowingLanguage,
            scriptLanguage: script?.language,
            scriptText: script?.text ?? "",
            systemLanguages: store.systemLanguages
        )
    }

    // MARK: - Captions and Clean Up

    /// What a take is heard in for captions and Clean Up: the script's language, or read from its
    /// text on Auto-detect; a take without a script, the Script Language new scripts start in, else
    /// the iPhone's. Neither Voice Following's language nor the interface's takes part.
    func captionRequest(for script: Script?) -> SpeechLanguageRequest {
        SpeechLanguageRequest(
            voiceFollowing: nil,
            scriptLanguage: script == nil ? scriptLanguage : script?.language,
            scriptText: script?.text ?? "",
            systemLanguages: store.systemLanguages
        )
    }

    // MARK: - Dictation

    /// What an idea spoken into the empty Scripts card is heard in: the language the script will be
    /// written in (`GenerateScriptViewModel` decides it the same way), so what is said and what comes
    /// back agree. The Script Language when one is set; else the language of what is already typed
    /// there (three words or more); else the interface's. Voice Following's language never takes part.
    func dictationRequest(existingText: String) -> SpeechLanguageRequest {
        if let scriptLanguage { return .language(scriptLanguage) }
        let typed = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if typed.split(whereSeparator: \.isWhitespace).count >= 3 || WordSegmenter.containsUnspacedScript(typed),
           let detected = LanguageDetector.language(in: typed) {
            return .language(detected)
        }
        return .language(interfaceLanguage)
    }

    /// When Voice Following listens for `script` in another language than its captions do (a
    /// Voice Following language picked in Language & Region), which two. Nil when they agree.
    func languageConflict(for script: Script?) -> SpeechLanguageConflict? {
        guard let script, let listening = voiceFollowingLanguage,
              let captions = script.language ?? LanguageDetector.language(in: script.text),
              captions != listening else { return nil }
        return SpeechLanguageConflict(voiceFollowing: listening, captions: captions)
    }

    // MARK: - Storage

    private static func interfaceLanguage(chosen: CueLanguage?, store: AppLanguageStoring) -> CueLanguage {
        chosen ?? CueLanguage.matching(interfaceLocalization: store.systemLocalization) ?? .english
    }

    private func save(_ language: CueLanguage?, key: String) {
        if let language {
            defaults.set(language.rawValue, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func load(key: String, from defaults: UserDefaults) -> CueLanguage? {
        defaults.string(forKey: key).flatMap(CueLanguage.init(rawValue:))
    }
}
