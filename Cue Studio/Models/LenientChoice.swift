//
//  LenientChoice.swift
//  Cue Studio
//

import Foundation

/// A choice saved in an edit (a filter, a font, a color, a transition…) from a list a newer version of Cue may add to. A
/// value this version doesn't know reads as `fallback`, noted in the read's `DecodingReport`, instead of failing what holds
/// it: an older build never hides a take, or drops a text, over one new font.
///
/// Only choices with a harmless stand-in are lenient. One whose stand-in would show something that isn't there (a sound
/// effect, a cover sticker, a language) stays strict, and the list holding it leaves just that element out (`LossyList`).
nonisolated protocol LenientChoice: RawRepresentable, Codable where RawValue == String {
    /// What a value this version doesn't know reads as.
    static var fallback: Self { get }
}

nonisolated extension LenientChoice {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let known = Self(rawValue: raw) {
            self = known
        } else {
            decoder.decodingReport?.note("\(Self.self) “\(raw)” read as “\(Self.fallback.rawValue)”")
            self = Self.fallback
        }
    }
}
