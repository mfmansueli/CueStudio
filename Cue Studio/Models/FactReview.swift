//
//  FactReview.swift
//  Cue Studio
//

import Foundation

/// The creator said they reviewed the claims of one version of a script's text ("I checked" on the fact-check reminder): which text, which
/// version and when. Hiding the reminder is never this: only the button records it, and an AI rewrite that changes the words brings the
/// reminder back (decision 9, 30/10/2026).
nonisolated struct FactReview: Codable, Hashable, Sendable {
    /// A digest of the words reviewed (`digest(of:)`), so a later text can be told apart without keeping a copy.
    let digest: String
    let version: Int
    let date: Date

    init(text: String, version: Int, date: Date) {
        digest = Self.digest(of: text)
        self.version = version
        self.date = date
    }

    /// Whether `text` is the very text that was reviewed.
    func covers(_ text: String) -> Bool { digest == Self.digest(of: text) }

    /// FNV-1a over the UTF-8 bytes, in hex: the same for the same words on every launch (`hashValue` isn't).
    static func digest(of text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
