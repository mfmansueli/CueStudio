//
//  SharedVideo.swift
//  Cue Studio
//

import Foundation

/// The exported video a destination is handed, with what the integrations need to know about it.
nonisolated struct SharedVideo: Equatable, Sendable {
    let operationID: UUID
    let url: URL
    /// The photo library's identifier for it, when it was saved there.
    let photosAssetID: String?
    let duration: TimeInterval
}
