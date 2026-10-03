//
//  CueLanguage.swift
//  Cue Studio
//

import Foundation

/// Every language Cue knows, in one place: the interface, Voice Following and scripts all name a
/// language with this type, and nothing else in the app writes a locale identifier by hand.
///
/// The three settings that use it stay independent (see `LanguageSettingsService`): the app can be
/// in English while a script is in Portuguese and Voice Following listens for Portuguese.
nonisolated enum CueLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    // The raw value is the interface localization (the String Catalog language), so it is also
    // what `AppleLanguages` and the app's `.lproj` folders use.
    case english = "en"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"
    case hindi = "hi"
    case indonesian = "id"
    case arabic = "ar"
    case turkish = "tr"
    case thai = "th"
    case vietnamese = "vi"

    var id: String { rawValue }

    /// The interface localization Cue ships for this language (`en.lproj`, `pt-BR.lproj`…).
    var localizationIdentifier: String { rawValue }

    /// The full locale for speech and content, with the region Apple's speech models use by default.
    var localeIdentifier: String {
        switch self {
        case .english: "en-US"
        case .spanish: "es-ES"
        case .portugueseBrazil: "pt-BR"
        case .french: "fr-FR"
        case .german: "de-DE"
        case .italian: "it-IT"
        case .japanese: "ja-JP"
        case .korean: "ko-KR"
        case .chineseSimplified: "zh-CN"
        case .hindi: "hi-IN"
        case .indonesian: "id-ID"
        case .arabic: "ar-SA"
        case .turkish: "tr-TR"
        case .thai: "th-TH"
        case .vietnamese: "vi-VN"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// ISO 639 code without region or script ("pt", "zh").
    var languageCode: String {
        switch self {
        case .portugueseBrazil: "pt"
        case .chineseSimplified: "zh"
        default: rawValue
        }
    }

    /// Brazilian Portuguese and Simplified Chinese are the variants Cue offers, so speech keeps
    /// their region. The other languages listen in the creator's own region when their iPhone lists
    /// one (English in the UK, Spanish in Mexico), as Voice Following always did.
    var keepsRegionForSpeech: Bool {
        self == .portugueseBrazil || self == .chineseSimplified
    }

    /// The language's name in itself, so anyone can find their own language in any interface.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .portugueseBrazil: "Português (Brasil)"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        case .hindi: "हिन्दी"
        case .indonesian: "Bahasa Indonesia"
        case .arabic: "العربية"
        case .turkish: "Türkçe"
        case .thai: "ไทย"
        case .vietnamese: "Tiếng Việt"
        }
    }

    /// The language's name in Cue's interface language.
    var label: String {
        switch self {
        case .english: String(localized: "English")
        case .spanish: String(localized: "Spanish")
        case .portugueseBrazil: String(localized: "Portuguese (Brazil)")
        case .french: String(localized: "French")
        case .german: String(localized: "German")
        case .italian: String(localized: "Italian")
        case .japanese: String(localized: "Japanese")
        case .korean: String(localized: "Korean")
        case .chineseSimplified: String(localized: "Chinese (Simplified)")
        case .hindi: String(localized: "Hindi")
        case .indonesian: String(localized: "Indonesian")
        case .arabic: String(localized: "Arabic")
        case .turkish: String(localized: "Turkish")
        case .thai: String(localized: "Thai")
        case .vietnamese: String(localized: "Vietnamese")
        }
    }

    /// English name, for instructions to the language model.
    var englishName: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .portugueseBrazil: "Brazilian Portuguese"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .chineseSimplified: "Simplified Chinese"
        case .hindi: "Hindi"
        case .indonesian: "Indonesian"
        case .arabic: "Arabic"
        case .turkish: "Turkish"
        case .thai: "Thai"
        case .vietnamese: "Vietnamese"
        }
    }

    var isRightToLeft: Bool { self == .arabic }

    // MARK: - Matching

    /// The Cue language for a locale or language identifier ("pt", "pt-PT", "zh-Hans-CN", "en_GB").
    /// Portuguese and Chinese map to the variant Cue offers; Traditional Chinese has none.
    init?(identifier: String) {
        let language = Locale.Language(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return nil }
        if code == "zh", let script = language.script?.identifier, script == "Hant" { return nil }
        if code == "zh", language.script == nil, let region = language.region?.identifier,
           ["TW", "HK", "MO"].contains(region) {
            return nil
        }
        guard let match = Self.allCases.first(where: { $0.languageCode == code }) else { return nil }
        self = match
    }
}
