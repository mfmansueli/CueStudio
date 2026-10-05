//
//  LanguageCapabilityService.swift
//  Cue Studio
//

import Foundation

/// The one place that knows what this device can do in each of Cue's languages: the interface, Apple
/// Intelligence writing, dictation, Voice Following, captions and translating captions. Each is asked of
/// the system on its own (`LanguageCapabilityChecking`), because none implies another: Apple Intelligence
/// writing in a language says nothing about speech recognition in it.
///
/// Answers are kept, so a screen that asks again (the language list, every time it opens) doesn't ask
/// the system again, and two screens asking at once share one question. What can change while the app
/// runs (a model finishing its download, Apple Intelligence turned on) is asked again after a short
/// while; what only an update, another iPhone or another language list changes is asked again when
/// the system version or the iPhone's languages change.
@MainActor
@Observable
final class LanguageCapabilityService {
    /// How long "model not installed yet" and "turned off" are trusted: a download or a switch in
    /// Settings can change them any moment.
    static let volatileLifetime: TimeInterval = 30

    private struct Key: Hashable {
        let feature: LanguageFeature?
        let language: CueLanguage?
        /// For translation: "source>target".
        let pair: String?
    }

    private struct Entry {
        let support: FeatureSupport
        let asked: Date
    }

    @ObservationIgnored private let checker: LanguageCapabilityChecking
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let environment: () -> String
    @ObservationIgnored private var environmentWhenAsked: String
    @ObservationIgnored private var inFlight: [Key: Task<FeatureSupport, Never>] = [:]
    private var entries: [Key: Entry] = [:]

    /// - Parameter environment: what changes the answers from outside the app (the system version, the
    ///   iPhone's languages); the answers are dropped when it changes.
    init(
        checker: LanguageCapabilityChecking = AppleLanguageCapabilityChecker(),
        now: @escaping () -> Date = { .now },
        environment: @escaping () -> String = {
            "\(ProcessInfo.processInfo.operatingSystemVersionString)|\(Locale.preferredLanguages.joined(separator: ","))"
        }
    ) {
        self.checker = checker
        self.now = now
        self.environment = environment
        environmentWhenAsked = environment()
    }

    // MARK: - Asking

    func support(_ feature: LanguageFeature, for language: CueLanguage) async -> FeatureSupport {
        await answer(Key(feature: feature, language: language, pair: nil)) { [checker] in
            await checker.support(feature, for: language)
        }
    }

    /// Whether captions in `source` can be translated into `target` here: both languages and the pair
    /// itself, as the Translation framework answers.
    func translation(from source: Locale.Language, to target: CueLanguage) async -> FeatureSupport {
        let pair = "\(source.maximalIdentifier)>\(target.locale.language.maximalIdentifier)"
        return await answer(Key(feature: nil, language: nil, pair: pair)) { [checker] in
            await checker.translation(from: source, to: target.locale.language)
        }
    }

    /// Everything this device does in `language`.
    func capabilities(of language: CueLanguage) async -> LanguageCapabilities {
        var support: [LanguageFeature: FeatureSupport] = [:]
        for feature in LanguageFeature.allCases {
            support[feature] = await self.support(feature, for: language)
        }
        return LanguageCapabilities(language: language, support: support)
    }

    /// What was last answered, for a screen that shows it without waiting; nil until asked.
    func known(_ feature: LanguageFeature, for language: CueLanguage) -> FeatureSupport? {
        let key = Key(feature: feature, language: language, pair: nil)
        guard let entry = entries[key], isFresh(entry) else { return nil }
        return entry.support
    }

    /// Asks again next time, whatever was kept (the creator came back from Settings, or a model arrived).
    func invalidate() {
        entries = [:]
    }

    // MARK: - Keeping answers

    private func answer(_ key: Key, _ ask: @escaping @Sendable () async -> FeatureSupport) async -> FeatureSupport {
        dropAnswersIfTheSystemChanged()
        if let entry = entries[key], isFresh(entry) { return entry.support }
        if let running = inFlight[key] { return await running.value }
        let task = Task { await ask() }
        inFlight[key] = task
        let support = await task.value
        inFlight[key] = nil
        entries[key] = Entry(support: support, asked: now())
        return support
    }

    private func isFresh(_ entry: Entry) -> Bool {
        switch entry.support {
        case .notInstalled, .unavailable(.turnedOff): now().timeIntervalSince(entry.asked) < Self.volatileLifetime
        case .supported, .unavailable: true
        }
    }

    private func dropAnswersIfTheSystemChanged() {
        let current = environment()
        guard current != environmentWhenAsked else { return }
        environmentWhenAsked = current
        entries = [:]
    }
}
