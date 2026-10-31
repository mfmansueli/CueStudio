//
//  WritingScript.swift
//  Cue Studio
//

import Foundation

/// The writing systems whose words the Latin faces can't draw and that Cue's languages write in: Japanese, Chinese (simplified
/// and traditional), Korean, Arabic, Devanagari (Hindi) and Thai. Each has its own library of faces (`FontPack`), offered
/// only to a creator who writes in it (`ScriptLibraryOffer`). Vietnamese, Turkish and the other Latin languages aren't here:
/// their letters are Latin ones (`ScriptFontCascade` swaps a face that lacks some of them for one like it that has them);
/// Cyrillic, Greek and Hebrew only reach a video typed by hand and draw in the system's faces.
nonisolated enum WritingScript: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case japanese, chineseSimplified, chineseTraditional, korean, arabic, devanagari, thai

    var id: String { rawValue }

    /// The library's heading in the pickers ("Japanese fonts").
    var libraryTitle: String {
        switch self {
        case .japanese: String(localized: "Japanese fonts")
        case .chineseSimplified: String(localized: "Chinese (Simplified) fonts")
        case .chineseTraditional: String(localized: "Chinese (Traditional) fonts")
        case .korean: String(localized: "Korean fonts")
        case .arabic: String(localized: "Arabic fonts")
        case .devanagari: String(localized: "Hindi fonts")
        case .thai: String(localized: "Thai fonts")
        }
    }

    /// A few letters a face is shown with in its own script, never translated.
    var sample: String {
        switch self {
        case .japanese: "あア字"
        case .chineseSimplified: "汉字"
        case .chineseTraditional: "漢字"
        case .korean: "한글"
        case .arabic: "أبجد"
        case .devanagari: "हिन्दी"
        case .thai: "ภาษา"
        }
    }

    /// The script `language` writes in; nil for a Latin language.
    static func of(_ language: CueLanguage) -> WritingScript? {
        switch language {
        case .japanese: .japanese
        case .chineseSimplified: .chineseSimplified
        case .chineseTraditional: .chineseTraditional
        case .korean: .korean
        case .arabic: .arabic
        case .hindi: .devanagari
        case .thai: .thai
        default: nil
        }
    }

    /// Which script Chinese characters with no kana around them are read in: the first of the creator's languages that writes
    /// them (Japanese, or Chinese in either form), else simplified Chinese.
    static func hanReading(for languages: [CueLanguage]) -> WritingScript {
        for language in languages {
            switch language {
            case .japanese: return .japanese
            case .chineseTraditional: return .chineseTraditional
            case .chineseSimplified: return .chineseSimplified
            default: continue
            }
        }
        return .chineseSimplified
    }

    /// The scripts `text` is written in, in the order they first appear. Chinese characters are Japanese in a text with kana,
    /// otherwise read as `han` says.
    static func scripts(in text: String, han: WritingScript = .chineseSimplified) -> [WritingScript] {
        var found: [WritingScript] = []
        var sawHan = false
        var sawKana = false
        for scalar in text.unicodeScalars {
            guard let kind = kind(of: scalar) else { continue }
            switch kind {
            case .han: sawHan = true
            case .kana: sawKana = true
            case .script(let script): if !found.contains(script) { found.append(script) }
            }
            // Han takes its place where it (or kana) first shows.
            if (kind == .han || kind == .kana) && !found.contains(where: \.writesHan) { found.append(.japanese) }
        }
        guard sawHan || sawKana, let index = found.firstIndex(of: .japanese) else { return found }
        found[index] = sawKana ? .japanese : (han.writesHan ? han : .chineseSimplified)
        return found
    }

    /// Whether `scalar` belongs to this script (Chinese characters count for Japanese and both Chinese).
    func contains(_ scalar: Unicode.Scalar) -> Bool {
        switch Self.kind(of: scalar) {
        case .han: writesHan
        case .kana: self == .japanese
        case .script(let script): script == self
        case nil: false
        }
    }

    /// Japanese and Chinese, which share their characters.
    var writesHan: Bool { self == .japanese || self == .chineseSimplified || self == .chineseTraditional }

    // MARK: - Private

    private enum Kind: Equatable {
        case han, kana, script(WritingScript)
    }

    private static func kind(of scalar: Unicode.Scalar) -> Kind? {
        switch scalar.value {
        case 0x3040...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9F: .kana
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x323AF: .han
        case 0x1100...0x11FF, 0x3130...0x318F, 0xA960...0xA97F, 0xAC00...0xD7AF, 0xD7B0...0xD7FF: .script(.korean)
        case 0x0600...0x06FF, 0x0750...0x077F, 0x0870...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF: .script(.arabic)
        case 0x0900...0x097F, 0xA8E0...0xA8FF: .script(.devanagari)
        case 0x0E00...0x0E7F: .script(.thai)
        default: nil
        }
    }
}
