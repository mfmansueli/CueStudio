//
//  ReadingLinePlacement.swift
//  Cue Studio
//

import Foundation

/// Where the Selfie reading line sits: where Cue recommends (just under the lens), or a distance
/// the creator chose.
nonisolated enum ReadingLinePlacement: Hashable, Sendable {
    case recommended
    /// Points below the front camera (see `PrompterSettings.readingLineOffset`).
    case offset(Double)

    init(offset: Double?) {
        self = offset.map { .offset($0) } ?? .recommended
    }

    var offset: Double? {
        switch self {
        case .recommended: nil
        case .offset(let points): points
        }
    }
}
