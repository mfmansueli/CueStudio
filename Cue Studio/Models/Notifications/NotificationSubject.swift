//
//  NotificationSubject.swift
//  Cue Studio
//

import Foundation

/// What a notification's words are about (`NotificationCopy`). Titles are only used when the creator allowed them in previews.
nonisolated enum NotificationSubject: Hashable, Sendable {
    /// A project at one of its stages: the words of that stage's campaign.
    case project(NotificationCampaign, title: String, network: ShareDestination?)
    /// No project to point at: the ways to start one.
    case entryPoint
    /// An idea the model wrote for one of the creator's topics.
    case idea(topic: String?)
    case feature(FeatureID)
    case yearReview(Int)
    case whatsNew(String)
}
