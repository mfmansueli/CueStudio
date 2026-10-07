//
//  SpeedScope.swift
//  Cue Studio
//

import Foundation

/// What a speed applies to.
enum SpeedScope: String, CaseIterable, Identifiable {
    /// The section under the playhead, or the one selected in Trim.
    case section
    case whole

    var id: String { rawValue }
}
