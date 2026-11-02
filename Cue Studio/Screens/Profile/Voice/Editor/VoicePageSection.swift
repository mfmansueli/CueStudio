//
//  VoicePageSection.swift
//  Cue Studio
//

import Foundation

/// The sections of the My Cue Voice page, in the order a creator thinks about themselves (the owner's item 10, 02/11/2026): who they are, who they
/// talk to, what about, how they sound, how they open and close, what else is true, what Cue never writes, and the examples.
enum VoicePageSection: String, CaseIterable, Identifiable {
    case whoYouAre, whoYouTalkTo, whatAbout, howYouSound, openAndClose, trueAboutYou, neverWrites, proof

    var id: String { rawValue }

    var rows: [VoicePageRow] {
        switch self {
        case .whoYouAre: [.role]
        case .whoYouTalkTo: [.audience, .watch, .reach]
        case .whatAbout: [.topics, .formats, .goals]
        case .howYouSound: [.tone, .style, .phrases]
        case .openAndClose: [.openings, .endings]
        case .trueAboutYou: [.notes, .stories]
        case .neverWrites: [.avoid]
        case .proof: [.examples, .learned]
        }
    }

    var title: String {
        switch self {
        case .whoYouAre: String(localized: "Who you are")
        case .whoYouTalkTo: String(localized: "Who you talk to")
        case .whatAbout: String(localized: "What about")
        case .howYouSound: String(localized: "How you sound")
        case .openAndClose: String(localized: "How you open and close")
        case .trueAboutYou: String(localized: "What’s true about you")
        case .neverWrites: String(localized: "What Cue never writes")
        case .proof: String(localized: "Examples and what Cue learned")
        }
    }
}
