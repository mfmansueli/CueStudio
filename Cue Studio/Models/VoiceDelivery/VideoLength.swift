//
//  VideoLength.swift
//  Cue Studio
//

import Foundation

nonisolated enum VideoLength: String, Codable, CaseIterable, Identifiable, Sendable {
    case under30, thirtyToSixty, oneToThree, longer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under30: String(localized: "Under 30 s")
        case .thirtyToSixty: String(localized: "30 to 60 s")
        case .oneToThree: String(localized: "1 to 3 min")
        case .longer: String(localized: "Longer")
        }
    }

    /// The seconds a script for a video that long should run (spoken: never below `ScriptRequestFactory.spokenFloor`); nil for "longer", which is the
    /// platform's own ideal.
    var targetRange: ClosedRange<TimeInterval>? {
        switch self {
        case .under30: 20...30
        case .thirtyToSixty: 30...60
        case .oneToThree: 60...180
        case .longer: nil
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .under30: "under 30 seconds"
        case .thirtyToSixty: "30 to 60 seconds"
        case .oneToThree: "1 to 3 minutes"
        case .longer: "longer than 3 minutes"
        }
    }
}
