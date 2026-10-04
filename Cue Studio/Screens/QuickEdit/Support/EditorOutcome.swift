//
//  EditorOutcome.swift
//  Cue Studio
//

import Foundation

/// How the creator left the editor, so the review they come back to can carry on: Done always asks
/// "Is it ready to post?" (never the back button), and each answer is a different next step.
enum EditorOutcome: String, Identifiable, CaseIterable {
    /// "Yes — share to social media": the edit is saved and "Share to" opens.
    case share
    /// "Download video": the edit is saved and the video goes to Photos (it counts as an export).
    case download
    /// "Ready, I'll post later": the edit is saved and the video waits in Ready.
    case ready
    /// "Not yet, I'll come back": the edit stays open as a draft (and the video stays in edit).
    case notYet
    /// The back button: the draft is kept and nothing is asked.
    case back

    var id: String { rawValue }

    /// Whether the edit is saved on the take (and the draft dropped).
    var savesTheEdit: Bool {
        switch self {
        case .share, .download, .ready: true
        case .notYet, .back: false
        }
    }

    /// The video the review comes back to is shared or saved by this answer, so the stage becomes SHARED.
    var exportsTheVideo: Bool {
        self == .share || self == .download
    }
}
