//
//  TestData.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Builders for test scenarios. Times are fixed so assertions never depend on the clock.
enum TestData {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// The rules shipped in the app bundle (the test host).
    static let rules = PlatformRulesService.bundledRules()

    static func preset(_ platform: Platform, monetizationGoals: Bool = true) -> PlatformPreset {
        rules.preset(for: platform, monetizationGoals: monetizationGoals)
    }

    /// A rules service that never reads a cache or the network.
    @MainActor
    static func rulesService() -> PlatformRulesService {
        PlatformRulesService(bundled: rules, cacheURL: nil, remoteURL: nil)
    }

    /// Language settings on `defaults`, with the interface language in memory (never the
    /// simulator's). The iPhone is in `systemLanguages`, and nothing else is chosen.
    @MainActor
    static func languages(
        defaults: UserDefaults, appLanguage: String? = nil,
        systemLocalization: String = "en", systemLanguages: [String] = ["en-US"]
    ) -> LanguageService {
        let store = InMemoryAppLanguageStore(
            chosenLocalization: appLanguage, systemLocalization: systemLocalization, systemLanguages: systemLanguages
        )
        return LanguageService(defaults: defaults, store: store)
    }

    /// "3.0" written the way the interface writes it: numbers follow the iPhone's region, so a
    /// simulator in Italy reads "3,0".
    static func decimal(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: Locale.interface.decimalSeparator ?? ".")
    }

    /// `count` spoken words.
    static func words(_ count: Int) -> String {
        Array(repeating: "word", count: count).joined(separator: " ")
    }

    static func script(
        title: String = "Test script",
        text: String = "Hook line.\n\nBody line.\n\nCall to action.",
        platform: Platform = .tiktok,
        type: ScriptType? = nil,
        version: Int = 1,
        folder: String? = nil,
        updatedAt: Date = now,
        language: CueLanguage? = nil,
        isFinished: Bool? = nil
    ) -> Script {
        Script(
            title: title, text: text, platform: platform, type: type, version: version, folder: folder,
            createdAt: updatedAt, updatedAt: updatedAt, language: language, isFinished: isFinished
        )
    }

    static func take(
        scriptID: UUID?,
        title: String = "Test script",
        number: Int = 1,
        recordedAt: Date = now,
        isBest: Bool = false
    ) -> Take {
        Take(
            scriptID: scriptID, scriptTitle: title, scriptVersion: 1, number: number, duration: 30,
            recordedAt: recordedAt, fileName: "take-\(UUID().uuidString).mov", isBest: isBest,
            resolution: .hd1080, frameRate: .fps30, aspect: .portrait, platform: .tiktok
        )
    }
}
