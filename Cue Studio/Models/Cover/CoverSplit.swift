//
//  CoverSplit.swift
//  Cue Studio
//

import Foundation

/// The second half of a before/after cover: its own picture (a frame or a photo) with its own framing, where the divider is,
/// and the two labels. The cover's own picture is the "before"; with no second picture yet, the same one shows on both sides.
nonisolated struct CoverSplit: Codable, Hashable, Sendable {
    static let positionRange: ClosedRange<Double> = 0.2...0.8

    var source: CoverSource?
    var framing = CoverFraming()
    /// Where the divider is, from the left, as a share of the cover's width.
    var position = 0.5
    var beforeLabel: String
    var afterLabel: String
    var showsLabels = true

    init(source: CoverSource? = nil) {
        self.source = source
        beforeLabel = String(localized: "BEFORE", comment: "Label on the left half of a before/after cover")
        afterLabel = String(localized: "AFTER", comment: "Label on the right half of a before/after cover")
    }
}
