//
//  VoyageStep.swift
//  Cue Studio
//

import Foundation

/// A step of the first voyage (the guide from a new creator's first script to their first video shared), in order. Each says what
/// it is, what the card says when it is next, and its button.
nonisolated enum VoyageStep: Int, Codable, CaseIterable, Identifiable, Sendable {
    case write, practice, record, pick, polish, share

    var id: Int { rawValue }

    /// 1 to 6.
    var number: Int { rawValue + 1 }

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
        case .write: String(localized: "An idea is enough: Cue helps with the rest")
        case .practice: String(localized: "Read it once; nothing is recorded")
        case .record: String(localized: "About a minute")
        case .pick: String(localized: "Mark the one you'll post with a star")
        case .polish: String(localized: "Captions and Clean Up · optional")
        case .share: String(localized: "Lights your first star")
        }
    }

    /// The card's line while this step is next.
    var next: String {
        switch self {
        case .write: String(localized: "Next: write your first script")
        case .practice: String(localized: "Next: practice it once")
        case .record: String(localized: "Next: record your first take")
        case .pick: String(localized: "Next: pick your best take")
        case .polish: String(localized: "Next: polish it")
        case .share: String(localized: "Next: share to your universe")
        }
    }

    /// Under that line.
    var nextDetail: String {
        switch self {
        case .write: String(localized: "Start from an idea, a blank page or something you wrote.")
        case .practice: String(localized: "Read your script on the teleprompter. Nothing is recorded.")
        case .record: String(localized: "Your script is ready on the teleprompter. A minute is enough.")
        case .pick: String(localized: "Watch it back and keep the one you'll post.")
        case .polish: String(localized: "Captions and Clean Up make it easier to watch. You can skip this.")
        case .share: String(localized: "Your video is ready. Sharing it lights your first star.")
        }
    }

    /// The card's button for this step.
    var action: String {
        switch self {
        case .write: String(localized: "Write")
        case .practice: String(localized: "Practice")
        case .record: String(localized: "Record")
        case .pick: String(localized: "Watch")
        case .polish: String(localized: "Polish")
        case .share: String(localized: "Share")
        }
    }
}
