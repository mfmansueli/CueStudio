//
//  ForegroundPresentation.swift
//  Cue Studio
//

import Foundation

/// How a notification that arrives while Cue is on screen shows. While the creator records, reads the teleprompter, edits, exports or
/// uses the remote, nothing makes a sound or covers the screen.
nonisolated enum ForegroundPresentation: Sendable {
    /// Banner and sound, as when Cue isn't open.
    case banner
    /// Only in Notification Center, silently.
    case listOnly
    /// Not shown now (a tool is introduced in the app later, at a quiet moment; a stale one isn't shown at all).
    case hidden
}
