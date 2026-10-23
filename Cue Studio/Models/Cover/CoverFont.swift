//
//  CoverFont.swift
//  Cue Studio
//

import Foundation

/// The typeface of a cover's words: one of the video's families (`TextOverlayFont.editorFonts`) at one of its weights,
/// heavy when the family has it. A cover saved when the cover had four faces of its own reads in the same ones: "grotesk"
/// is Space Grotesk Bold, "serif" DM Serif Display, "system" SF Pro Heavy.
nonisolated struct CoverFont: Codable, Hashable, Sendable {
    var face: TextOverlayFont
    var weight: TextOverlayWeight

    /// `face` at `weight` when it has it, else at its heaviest.
    init(_ face: TextOverlayFont, weight: TextOverlayWeight? = nil) {
        self.face = face
        self.weight = weight.flatMap { face.weights.contains($0) ? $0 : nil } ?? face.weights.last ?? .regular
    }

    static let anton = CoverFont(.anton)
    static let grotesk = CoverFont(.spaceGrotesk, weight: .bold)
    static let serif = CoverFont(.dmSerif)
    static let system = CoverFont(.sfPro, weight: .heavy)

    var label: String { face.label }

    /// Condensed type, which sits tighter.
    var isCondensed: Bool { face == .anton || face == .bangers }

    /// A serif, whose letters from the system's fallback come semibold rather than heavy.
    var isSerif: Bool { face == .dmSerif || face == .instrumentSerif }

    private static let legacy: [String: CoverFont] = ["anton": .anton, "grotesk": .grotesk, "serif": .serif, "system": .system]

    private enum CodingKeys: String, CodingKey {
        case face, weight
    }

    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let name = try? single.decode(String.self) {
            self = Self.legacy[name] ?? CoverFont(TextOverlayFont(rawValue: name) ?? .anton)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            try container.decode(TextOverlayFont.self, forKey: .face), weight: try container.decodeIfPresent(TextOverlayWeight.self, forKey: .weight)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(face, forKey: .face)
        try container.encode(weight, forKey: .weight)
    }
}
