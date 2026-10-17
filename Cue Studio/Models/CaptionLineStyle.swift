//
//  CaptionLineStyle.swift
//  Cue Studio
//

import Foundation

/// How one caption line stands out from the others (set on several lines at once with Select, as CapCut's caption batch edit
/// does): the whole line lit in the captions' highlight color, the way the word being said is, and bigger type. Everything
/// else (font, plate, place, how lines appear) stays the collection's, so a styled line never reads as another video's.
/// Lines saved before it have none (`CaptionCue.lineStyle` nil).
nonisolated struct CaptionLineStyle: Codable, Hashable, Sendable {
    /// How big a line's type is next to the others. Never smaller: a smaller line would fall under the size its colors are
    /// measured at.
    enum Size: String, Codable, CaseIterable, Identifiable, Sendable {
        case regular, bigger, biggest

        var id: String { rawValue }

        /// Times the collection's size (`CaptionSettings.sizeScale`; the result is kept inside its range).
        var scale: Double {
            switch self {
            case .regular: 1
            case .bigger: 1.25
            case .biggest: 1.5
            }
        }

        var label: String {
            switch self {
            case .regular: String(localized: "Regular")
            case .bigger: String(localized: "Bigger")
            case .biggest: String(localized: "Biggest")
            }
        }
    }

    /// The whole line in the highlight color (or boxed, where the style boxes the word said), instead of word by word.
    var isEmphasized = false
    var size: Size = .regular

    /// A style that changes nothing reads as none.
    var isPlain: Bool { !isEmphasized && size == .regular }

    private enum CodingKeys: String, CodingKey {
        case isEmphasized, size
    }

    init(isEmphasized: Bool = false, size: Size = .regular) {
        self.isEmphasized = isEmphasized
        self.size = size
    }

    /// A size this version doesn't know reads as regular, never as a broken line.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEmphasized = (try? container.decodeIfPresent(Bool.self, forKey: .isEmphasized)) ?? false
        size = (try? container.decodeIfPresent(Size.self, forKey: .size)) ?? .regular
    }
}
