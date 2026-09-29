//
//  CoverSource.swift
//  Cue Studio
//

import Foundation

/// Where a cover's picture comes from.
nonisolated enum CoverSource: Codable, Hashable, Sendable {
    /// A frame of the recording, at this second.
    case frame(TimeInterval)
    /// A photo from the library, copied into `EditMediaFiles`.
    case photo(fileName: String)
}
