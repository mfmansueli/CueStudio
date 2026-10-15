//
//  CatchphraseTrim.swift
//  Cue Studio
//

import Foundation

/// A line with the creator's catchphrase taken off its front: where the catchphrase goes is the script's to decide. Given a voice, the model started
/// every idea's opening line with it ("Fala, galera! …", 24 of 72 ideas with a voice in the baseline run; none after). Taking it off the creator's
/// examples too was tried and changed nothing (a creator whose examples all open with it still got it first in 2 scripts of 3). Left as it is when
/// too little would remain.
nonisolated enum CatchphraseTrim {
    /// The fewest words worth keeping after the catchphrase.
    static let fewestWords = 3

    static func trimmingLeading(_ text: String, phrases: [String]) -> String {
        for phrase in phrases {
            let core = phrase.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
            guard core.count >= 3, let range = text.range(of: core, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) else { continue }
            let rest = String(text[range.upperBound...].drop { $0.isPunctuation || $0.isWhitespace })
            guard rest.split(separator: " ").count >= fewestWords else { return text }
            return rest.prefix(1).uppercased() + rest.dropFirst()
        }
        return text
    }
}
