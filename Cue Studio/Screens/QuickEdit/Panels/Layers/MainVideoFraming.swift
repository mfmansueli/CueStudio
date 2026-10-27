//
//  MainVideoFraming.swift
//  Cue Studio
//

import Foundation

/// How the main video's recording `sourceID` (nil: the take) sits in its split screen area, on its face: found before a support
/// goes in, written with it (`OverlaysViewModel.add`, `setMediaLayout`).
nonisolated struct MainVideoFraming: Equatable, Sendable {
    let sourceID: UUID?
    let framing: AreaFraming
}
