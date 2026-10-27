//
//  TextBlock.swift
//  Cue Studio
//

import Foundation

/// A text's block once it is resized as a whole (two fingers, the corner handle) or made wider or narrower (the side
/// handles): how long its lines can be, measured at a size. Everything the text draws (its line length, its box's padding
/// and corners, its shadow, outline and glow) then grows with its size from that one, so a text twice as big is the same
/// text twice as big, its lines breaking where they did. A text without one sizes its lines to the frame
/// (`TextOverlayRenderer.maxWidthFraction`), as texts always did.
nonisolated struct TextBlock: Codable, Hashable, Sendable {
    /// Narrowest a line can be, in points on the design's frame at `size`.
    static let minimumWidth: Double = 24

    /// The longest a line can be, in points on the design's 402-point frame, at `size`.
    var width: Double
    /// The text's size when `width` was measured.
    var size: Double

    init(width: Double, size: Double) {
        self.width = max(Self.minimumWidth, width.isFinite ? width : Self.minimumWidth)
        self.size = max(1, size.isFinite ? size : 1)
    }

    /// How much bigger the text is now than when its block was measured.
    func scale(at textSize: Double) -> Double {
        max(0.01, textSize / size)
    }

    private enum CodingKeys: String, CodingKey {
        case width, size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try container.decode(Double.self, forKey: .width), size: try container.decode(Double.self, forKey: .size))
    }
}
