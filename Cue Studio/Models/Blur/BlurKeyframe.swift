//
//  BlurKeyframe.swift
//  Cue Studio
//

import Foundation

/// Where a Blur area is at a moment of its footage: its box on the upright picture (fractions from the top left). Set by
/// following the subject, or by the creator dragging it at that moment (`isSet`), which following again never moves.
nonisolated struct BlurKeyframe: Codable, Hashable, Sendable {
    /// Seconds of the footage.
    var time: TimeInterval
    var box: NormalizedBox
    /// The creator put it here; nil or false: following did.
    var isSet: Bool?

    init(time: TimeInterval, box: NormalizedBox, isSet: Bool? = nil) {
        self.time = time
        self.box = box
        self.isSet = isSet
    }
}
