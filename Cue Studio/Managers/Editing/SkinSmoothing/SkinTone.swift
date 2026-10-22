//
//  SkinTone.swift
//  Cue Studio
//

import Foundation

/// A face's own skin tone and how noisy its picture is, measured once per detection on what is surely skin: the centre of its color (the chroma of
/// YCbCr, which is much the same across light and dark skin, and its brightness) and how far from it a pixel may be and still be skin. Everything is in
/// sRGB-encoded values, 0 to 1, the scale the filter works on.
nonisolated struct SkinTone: Hashable, Sendable {
    /// The centre of the skin's chroma (blue and red differences, from −0.5 to 0.5) and its brightness.
    var cb: Double
    var cr: Double
    var luma: Double
    /// Closer than this to the centre in chroma is skin for sure; the gate closes over the next `chromaFade`.
    var chromaReach: Double
    /// How much of the fine detail in the skin is noise (the same units as the detail the filter reads).
    var noise: Double

    static let chromaFade = 0.05
}
