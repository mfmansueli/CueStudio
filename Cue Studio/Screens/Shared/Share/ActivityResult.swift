//
//  ActivityResult.swift
//  Cue Studio
//

import Foundation

/// How the system share sheet ended. Only `completed` means an activity took the item; even then it says nothing about
/// whether anything was published.
nonisolated enum ActivityResult: Equatable, Sendable {
    /// An activity accepted the items. `activityType` is its identifier (nil when the system doesn't give one).
    case completed(activityType: String?)
    /// The sheet was dismissed without an activity finishing.
    case cancelled
    case failed

    /// `completionWithItemsHandler`'s three arguments, told apart: an error is a failure even if the flag is set.
    init(activityType: String?, completed: Bool, error: Error?) {
        if error != nil {
            self = .failed
        } else if completed {
            self = .completed(activityType: activityType)
        } else {
            self = .cancelled
        }
    }
}
