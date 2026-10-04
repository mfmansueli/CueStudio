//
//  TakeStage.swift
//  Cue Studio
//

import Foundation

/// Where a video (the takes of one script) is on its way out: pick the best take, edit, ready to
/// post, shared. **Never set by hand**: it is read from what the creator did, so it can't drift.
nonisolated enum TakeStage: Int, CaseIterable, Identifiable, Comparable, Sendable {
    case pick, edit, ready, shared

    var id: Int { rawValue }

    static func < (lhs: TakeStage, rhs: TakeStage) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The first rule that matches wins: more than one take and none starred is **pick**; an edit
    /// still open (a Quick edit draft on any of the takes) is **edit**; nothing exported yet is
    /// **ready**; otherwise **shared**.
    init(takes: [Take], hasDraft: (UUID) -> Bool) {
        if takes.count > 1 && !takes.contains(where: \.isBest) {
            self = .pick
        } else if takes.contains(where: { hasDraft($0.id) }) {
            self = .edit
        } else if !takes.contains(where: \.isExported) {
            self = .ready
        } else {
            self = .shared
        }
    }

    /// The pipeline header: "TO PICK", "IN EDIT", "READY", "SHARED".
    var pipelineLabel: String {
        switch self {
        case .pick: String(localized: "To pick")
        case .edit: String(localized: "In edit")
        case .ready: String(localized: "Ready")
        case .shared: String(localized: "Shared")
        }
    }

    /// The pill on a video's poster: "PICK BEST", "IN EDIT", "READY", "SHARED".
    var badgeLabel: String {
        switch self {
        case .pick: String(localized: "Pick best")
        case .edit: String(localized: "In edit")
        case .ready: String(localized: "Ready")
        case .shared: String(localized: "Shared")
        }
    }

    /// The step bar in the take review: "PICK", "EDIT", "READY", "SHARED".
    var stepLabel: String {
        switch self {
        case .pick: String(localized: "Pick")
        case .edit: String(localized: "Edit")
        case .ready: String(localized: "Ready")
        case .shared: String(localized: "Shared")
        }
    }

    /// What VoiceOver reads for the stage.
    var sentence: String {
        switch self {
        case .pick: String(localized: "Pick your best take")
        case .edit: String(localized: "In edit")
        case .ready: String(localized: "Ready to post")
        case .shared: String(localized: "Shared")
        }
    }

    /// What the "NEXT" line asks for when a video waits in this stage; nil when nothing waits
    /// (shared videos are done).
    var nextVerb: String? {
        switch self {
        case .pick: String(localized: "Pick the best take")
        case .edit: String(localized: "Finish the edit")
        case .ready: String(localized: "Post it")
        case .shared: nil
        }
    }

    /// The title and the line under it when a stage has no video (a stage picked in the pipeline).
    var emptyTitle: String {
        switch self {
        case .pick, .edit: String(localized: "All caught up")
        case .ready: String(localized: "Nothing ready yet")
        case .shared: String(localized: "Nothing here yet")
        }
    }

    var emptyDetail: String {
        switch self {
        case .pick: String(localized: "Every video has a best take.")
        case .edit: String(localized: "No edits waiting.")
        case .ready: String(localized: "Tap Done in the editor, or pick a best take — it lands here, ready to post.")
        case .shared: String(localized: "Nothing shared yet.")
        }
    }
}
