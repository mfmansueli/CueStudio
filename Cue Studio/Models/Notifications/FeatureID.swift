//
//  FeatureID.swift
//  Cue Studio
//

import Foundation

/// A tool Cue can introduce (`FeatureCatalog`). Stable raw values: they are kept in the exposure history and sent as the campaign
/// of a notification ("discover.cleanUp").
nonisolated enum FeatureID: String, Codable, CaseIterable, Identifiable, Sendable {
    case myCueVoice
    case importWriting
    case ideas
    case logbook
    case voiceFollowing
    case cleanUp
    case autoCaptions
    case captionTranslation
    case studioVoice
    case skinSmoothing
    case backgrounds
    case covers
    case layers
    case voiceOver
    case remoteControl
    case safeZones
    case yourUniverse

    var id: String { rawValue }
}
