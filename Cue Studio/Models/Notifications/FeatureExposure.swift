//
//  FeatureExposure.swift
//  Cue Studio
//

import Foundation

/// One time a tool was put in front of the creator: a discovery notification whose time passed, or its introduction in the app. Two in
/// 90 days at most, 30 days apart (`NotificationPolicy`).
nonisolated struct FeatureExposure: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case notification
        case inApp
    }

    var feature: FeatureID
    var date: Date
    var kind: Kind
}
