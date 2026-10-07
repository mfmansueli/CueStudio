//
//  CleanUpSection.swift
//  Cue Studio
//

import Foundation

/// Clean Up's two views of the same listening: the pauses, taken out together after a preview,
/// and the words to review one by one (filler words and possible retakes).
enum CleanUpSection: String, CaseIterable, Identifiable {
    case pauses, review

    var id: String { rawValue }
}
