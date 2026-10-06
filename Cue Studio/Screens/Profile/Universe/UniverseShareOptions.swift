//
//  UniverseShareOptions.swift
//  Cue Studio
//

import Foundation

/// What the card of "Share my {year} universe" is made as (9.2): an image or a 6 s video, with or without the numbers and the @handle.
nonisolated struct UniverseShareOptions: Equatable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case image, video

        var id: String { rawValue }
    }

    var kind: Kind = .image
    var showsNumbers = true
    var showsHandle = true

    /// The video's length and the time the map takes to build before it holds.
    static let videoDuration: TimeInterval = 6
    static let buildDuration: TimeInterval = 4.5
    /// The card is laid out at 405 × 720 and rendered at 1080 × 1920.
    static let cardSize = CGSize(width: 405, height: 720)
    static let outputSize = CGSize(width: 1080, height: 1920)
}
