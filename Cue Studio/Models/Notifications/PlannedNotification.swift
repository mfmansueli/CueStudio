//
//  PlannedNotification.swift
//  Cue Studio
//

import Foundation

/// A candidate the planner gave a time to.
nonisolated struct PlannedNotification: Hashable, Sendable {
    var candidate: CampaignCandidate
    var fireDate: Date
}
