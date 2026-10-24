//
//  MediaPartChoice.swift
//  Cue Studio
//

import Foundation

/// A video picked to replace a clip or a photo or video, waiting for its part to be chosen: the slot keeps its length, and the
/// creator slides which part of the new video fills it (`MediaPartSheet`).
nonisolated struct MediaPartChoice: Identifiable, Equatable, Sendable {
    enum Purpose: Equatable, Sendable {
        /// The photo or video `id` laid over the take.
        case replaceMedia(UUID)
        /// The clip `id` of the sequence (it plays its recording's seconds: `length` is of the new video, at the clip's speed).
        case replaceClip(UUID)
    }

    let id = UUID()
    let purpose: Purpose
    var pick: MediaPick
    /// How long the part is: the slot's.
    let length: TimeInterval
}
