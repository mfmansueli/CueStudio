//
//  ImportedTakeVideo.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A video copied in from Photos to become a take: its file and what the library records of it.
nonisolated struct ImportedTakeVideo: Sendable {
    let url: URL
    let duration: TimeInterval
    let uprightSize: CGSize
    let frameRate: Double
}
