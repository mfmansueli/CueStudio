//
//  VoyageStep.swift
//  Cue Studio
//

import Foundation

/// A step of the first voyage (the guide from a new creator's first script to their first video shared), in order. Each says what it
/// is in the list of steps, and what its tip says: short, so it fits in every language, and always with the creator doing the work
/// and Cue helping (`DESIGN_PROJECT.md` §33).
nonisolated enum VoyageStep: Int, Codable, CaseIterable, Identifiable, Sendable {
    case write, practice, record, pick, polish, share

    var id: Int { rawValue }

    /// 1 to 6.
    var number: Int { rawValue + 1 }

    /// The step after this one; nil for the last.
    var following: VoyageStep? { VoyageStep(rawValue: rawValue + 1) }

    var title: String {
        switch self {
        case .write: String(localized: "Write your first script")
        case .practice: String(localized: "Practice with the teleprompter")
        case .record: String(localized: "Record a take")
        case .pick: String(localized: "Pick your best take")
        case .polish: String(localized: "Polish it")
        case .share: String(localized: "Share to your universe")
        }
    }

    /// Under the title in the list of steps, while it is still ahead.
    var detail: String {
        switch self {
        case .write: String(localized: "An idea is enough. You make it yours.")
        case .practice: String(localized: "Read it once; nothing is recorded")
        case .record: String(localized: "About a minute")
        case .pick: String(localized: "Mark the one you'll post with a star")
        case .polish: String(localized: "Captions and Clean Up · optional")
        case .share: String(localized: "Lights your first star")
        }
    }

    /// The symbol in the tip's tile.
    var symbol: String {
        switch self {
        case .write: "sparkles"
        case .practice: "text.alignleft"
        case .record: "record.circle"
        case .pick: "star"
        case .polish: "captions.bubble"
        case .share: "paperplane"
        }
    }

    /// The tip's title. `network` is the take's platform, for Share.
    func tipTitle(network: String? = nil) -> String {
        switch self {
        case .write: String(localized: "Your idea, Cue's draft.")
        case .practice: String(localized: "Read it out loud once")
        case .record: String(localized: "Now, for real")
        case .pick: String(localized: "Which take is the one?")
        case .polish: String(localized: "Make it work muted")
        case .share:
            if let network { String(localized: "Ready for \(network)") } else { String(localized: "Ready to share") }
        }
    }

    /// The tip's line. `duration` is how long the script reads ("0:44"), for Practice; `network` the take's platform, for Share.
    func tipMessage(duration: String? = nil, network: String? = nil) -> String {
        switch self {
        case .write: return String(localized: "Make it yours. Cue learns as you write.")
        case .practice:
            guard let duration else { return String(localized: "The text follows your voice. Nothing is recorded.") }
            return String(localized: "The text follows your voice. \(duration), nothing recorded.")
        case .record: return String(localized: "Redo it as often as you like. You pick the take that's posted.")
        case .pick: return String(localized: "Star your favorite. The others stay in Takes.")
        case .polish: return String(localized: "Cue drafts captions from your voice. Fix any word.")
        case .share:
            guard let network else { return String(localized: "Cue opens the app with your video and caption. You post.") }
            return String(localized: "Cue opens \(network) with your video and caption. You post.")
        }
    }

    /// The tip's button where it leads somewhere else (on Scripts and Takes). `canCompare`: the take has siblings to compare with.
    func tipAction(canCompare: Bool = false) -> String {
        switch self {
        case .write: String(localized: "Get an idea")
        case .practice: String(localized: "Try it")
        case .record: String(localized: "Record")
        case .pick:
            if canCompare { String(localized: "Compare") } else { String(localized: "Watch") }
        case .polish: String(localized: "Add captions")
        case .share: String(localized: "Share")
        }
    }
}
