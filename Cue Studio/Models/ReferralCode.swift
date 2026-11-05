//
//  ReferralCode.swift
//  Cue Studio
//

import Foundation

/// An invite code as Cue's server makes them (`server/functions/src/referralCode.ts`): six characters a friend can read aloud and type
/// without mistaking one for another (no I, O, 0 or 1). What a friend types is read without spaces, dashes or case.
nonisolated enum ReferralCode {
    static let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    static let length = 6

    /// The code in what the friend typed, or nil when it can't be one.
    static func normalized(_ typed: String) -> String? {
        let code = typed.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard code.count == length, code.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return code
    }
}
