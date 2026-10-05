//
//  ExportPhase.swift
//  Cue Studio
//

import Foundation

/// Where an export is, from the creator's tap to the end. Each case is a different thing to tell: only
/// `delivered` means the video left Cue, and no case says it was published, because no platform reports that.
nonisolated enum ExportPhase: Equatable, Sendable {
    case idle
    /// Rendering the file (or reusing the one already made for the same edit and settings).
    case preparing
    case savingToPhotos
    /// Handed to another app or the share sheet; the result isn't known yet.
    case delivering(ShareDestination?)
    case cancelled
    case failed
    case delivered(DeliveryEvidence)
}
