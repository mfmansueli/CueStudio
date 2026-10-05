//
//  CueLanguage.swift
//  Cue Studio
//

import Foundation

/// A language Cue works in. One list for everything language-aware: the interface, Voice Following,
/// scripts, captions, translation and AI writing. No other type keeps its own list of languages or
/// locale identifiers.
///
/// The raw value is the script and speech locale (BCP 47), so a script saved as `"pt-BR"` reads the
/// same everywhere.
nonisolated enum CueLanguage: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case english = "en-US"
    case spanish = "es-ES"
    case portugueseBrazil = "pt-BR"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case chineseSimplified = "zh-CN"
    case hindi = "hi-IN"
    case indonesian = "id-ID"
    case arabic = "ar-SA"
    case turkish = "tr-TR"
    case thai = "th-TH"
    case vietnamese = "vi-VN"
    case chineseTraditional = "zh-TW"
    case dutch = "nl-NL"
    case swedish = "sv-SE"
    case danish = "da-DK"
    case norwegian = "nb-NO"

    var id: String { rawValue }

    // MARK: - Identifiers

    /// The locale of content in this language: scripts, captions, AI writing.
    var localeIdentifier: String { rawValue }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// The locale Apple's speech recognition is asked for. These are the identifiers the Speech
    /// framework lists (`SpeechTranscriber` / `DictationTranscriber`); whether one is available
    /// on a given device is always asked at runtime (`SpeechLocaleResolver`).
    var speechLocale: Locale { locale }

    /// The `.lproj` the interface uses: the String Catalogs' language.
    var interfaceLocalization: String {
        switch self {
        case .english: "en"
        case .spanish: "es"
        case .portugueseBrazil: "pt-BR"
        case .french: "fr"
        case .german: "de"
        case .italian: "it"
        case .japanese: "ja"
        case .korean: "ko"
        case .chineseSimplified: "zh-Hans"
        case .hindi: "hi"
        case .indonesian: "id"
        case .arabic: "ar"
        case .turkish: "tr"
        case .thai: "th"
        case .vietnamese: "vi"
        case .chineseTraditional: "zh-Hant"
        case .dutch: "nl"
        case .swedish: "sv"
        case .danish: "da"
        case .norwegian: "nb"
        }
    }

    /// ISO 639 code ("pt", "zh"), for matching a detected or preferred language.
    var languageCode: String {
        String(rawValue.prefix { $0 != "-" })
    }

    // MARK: - Names

    /// The language's name in itself, as language pickers show it ("Português (Brasil)").
    /// Never translated.
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
        case .chineseTraditional: "繁體中文"
        case .dutch: "Nederlands"
        case .swedish: "Svenska"
        case .danish: "Dansk"
        case .norwegian: "Norsk bokmål"
        }
    }

    /// The language's name in the interface language ("Portuguese (Brazil)" in English,
    /// "Portugiesisch (Brasilien)" in German). Foundation names every language in every language.
    var localizedName: String {
        name(in: InterfaceLocale.current ?? .current)
    }

    /// The name in English, for AI instructions ("Write the script in Portuguese (Brazil).").
    var englishName: String {
        name(in: Locale(identifier: "en"))
    }

    func name(in locale: Locale) -> String {
        let name = locale.localizedString(forIdentifier: interfaceLocalization) ?? nativeName
        // Some languages write language names in lowercase ("portugués"); a list item starts upper.
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    // MARK: - Writing

    /// Read and laid out right to left (the interface mirrors, scripts align right).
    var isRightToLeft: Bool { self == .arabic }

    /// Written without spaces between words, so words are found by a dictionary (`WordSegmenter`)
    /// rather than by whitespace.
    var writesWithoutSpaces: Bool {
        switch self {
        case .japanese, .chineseSimplified, .chineseTraditional, .thai: true
        default: false
        }
    }

    /// Chinese is one language in two writing systems; speech, detection and translation tell them apart.
    var isChinese: Bool { self == .chineseSimplified || self == .chineseTraditional }

    /// How Natural Language and Translation name this Chinese writing system; nil for other languages.
    var chineseScriptIdentifier: String? {
        switch self {
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        default: nil
        }
    }

    // MARK: - Matching

    /// The language for a language code ("pt", "pt-PT", "zh-Hans"…), or nil when Cue doesn't offer it.
    static func matching(languageCode code: String) -> CueLanguage? {
        matching(language: Locale.Language(identifier: code))
    }

    /// The language for a `Locale.Language`, keeping the writing system where a language has two:
    /// Chinese is Traditional by script or region (zh-Hant, zh-TW, zh-HK, zh-MO), Simplified otherwise.
    static func matching(language: Locale.Language) -> CueLanguage? {
        guard let code = language.languageCode?.identifier else { return nil }
        // "no" is Norwegian in general; Cue offers Bokmål.
        if code == "no" || code == "nb" || code == "nn" { return .norwegian }
        if code == "zh" {
            let isTraditional = language.script?.identifier == "Hant" || ["TW", "HK", "MO"].contains(language.region?.identifier ?? "")
            return isTraditional ? .chineseTraditional : .chineseSimplified
        }
        return allCases.first { $0.languageCode == code }
    }

    /// The interface language for an `.lproj` name ("pt-BR", "zh-Hans"), or nil when Cue isn't
    /// translated into it.
    static func matching(interfaceLocalization localization: String) -> CueLanguage? {
        allCases.first { $0.interfaceLocalization.caseInsensitiveCompare(localization) == .orderedSame }
            ?? matching(languageCode: localization)
    }

    /// The creator's own regional variant of this language among `preferred` (the iPhone's language
    /// list, "en-GB" or "es-MX"), or nil when the list has none. Only a language the creator listed
    /// counts, never the device's country, which says nothing about the audience of a script. A
    /// variant Cue writes differently (pt-PT for pt-BR, Simplified for Traditional) is not one of this
    /// language's, unless `acceptingAnyVariant`: a language read from the text alone (Auto-detect)
    /// only says "Portuguese", and the creator's own Portuguese is as good as Cue's.
    func variant(among preferred: [String], acceptingAnyVariant: Bool = false) -> Locale? {
        for identifier in preferred {
            let locale = Locale(identifier: identifier)
            guard locale.language.languageCode?.identifier == languageCode, locale.region != nil else { continue }
            if isChinese, !accepts(locale) { continue }
            guard acceptingAnyVariant || accepts(locale) else { continue }
            return locale
        }
        return nil
    }

    /// True when `locale` is this language as written here: the same language, and for Portuguese
    /// and Chinese the same variant (pt-BR, not pt-PT; Simplified, not Traditional). Recognition in
    /// another variant would be recognition in another language.
    func accepts(_ locale: Locale) -> Bool {
        guard locale.language.languageCode?.identifier == languageCode else { return false }
        switch self {
        case .portugueseBrazil:
            return locale.region?.identifier == "BR"
        case .chineseSimplified:
            let script = locale.language.maximalIdentifier
            return locale.region?.identifier == "CN" || script.contains("Hans")
        case .chineseTraditional:
            let script = locale.language.maximalIdentifier
            return ["TW", "HK", "MO"].contains(locale.region?.identifier ?? "") || script.contains("Hant")
        case .norwegian:
            return ["nb", "no"].contains(locale.language.languageCode?.identifier ?? "")
        default:
            return true
        }
    }
}
