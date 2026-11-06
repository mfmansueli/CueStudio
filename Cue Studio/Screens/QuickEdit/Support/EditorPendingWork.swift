//
//  EditorPendingWork.swift
//  Cue Studio
//

import Foundation

/// Work the editor started that changes the edit when it ends: Done waits for it (the video would go out without it) and says
/// what is missing; Back keeps the draft, stops it and says what didn't finish. Measurements that only suggest (Clean Up
/// listening, beats, Studio Voice's Compare) aren't any: nothing of the edit is lost when they stop.
nonisolated enum EditorPendingWork: Equatable, Sendable {
    /// Captions listening to the take (or a video's voice).
    case captions
    /// Captions being translated.
    case translation
    /// Track following an object for a text, graphic or photo.
    case tracking
    /// A Blur area following its subject.
    case blurArea
    /// A clip being made: reversed, a freeze frame, a sound pulled out, a photo or video coming in.
    case clip
    /// Auto measuring the picture (Adjust).
    case auto

    /// Said on Done, which waits.
    var waitMessage: String {
        switch self {
        case .captions: String(localized: "Captions are still being made · Wait a moment")
        case .translation: String(localized: "Captions are still being translated · Wait a moment")
        case .tracking: String(localized: "Tracking is still running · Wait a moment")
        case .blurArea: String(localized: "A Blur area is still being tracked · Wait a moment")
        case .clip: String(localized: "A clip is still being prepared · Wait a moment")
        case .auto: String(localized: "Auto is still measuring the picture · Wait a moment")
        }
    }

    /// Said on Back, which stops it (the draft keeps everything else).
    var stoppedMessage: String {
        switch self {
        case .captions: String(localized: "Draft saved · Captions weren't finished")
        case .translation: String(localized: "Draft saved · The translation wasn't finished")
        case .tracking: String(localized: "Draft saved · Tracking wasn't finished")
        case .blurArea: String(localized: "Draft saved · The Blur area wasn't tracked to the end")
        case .clip: String(localized: "Draft saved · A clip being prepared was stopped")
        case .auto: String(localized: "Draft saved · Auto wasn't finished")
        }
    }
}
