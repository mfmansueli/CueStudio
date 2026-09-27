//
//  TakeLibraryView.swift
//  Cue Studio
//

import Foundation

/// The second filter row in Takes: every video, only those with a best take, not shared yet, or
/// edited.
nonisolated enum TakeLibraryView: String, CaseIterable, Identifiable, Sendable {
    case all, best, notShared, edited

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "All takes")
        case .best: String(localized: "★ Best")
        case .notShared: String(localized: "Not shared")
        case .edited: String(localized: "Edited")
        }
    }

    func matches(_ video: TakeVideo) -> Bool {
        switch self {
        case .all: true
        case .best: video.hasMarkedBest
        case .notShared: video.isNotShared
        case .edited: video.isEdited
        }
    }
}
