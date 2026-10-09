//
//  IdeaKey.swift
//  Cue Studio
//

import Foundation

/// A short, stable name for an idea the model wrote, so a notification can point at it without carrying its words: a 64-bit FNV-1a of the
/// idea's own identity, in hex. The idea is found again by this key when the notification is opened.
nonisolated enum IdeaKey {
    static func of(_ idea: ThemeIdea) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in idea.id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
