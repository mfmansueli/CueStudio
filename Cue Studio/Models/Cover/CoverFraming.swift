//
//  CoverFraming.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How a cover's picture sits in its frame: zoomed in (1 fills the frame, as the picture is drawn by default) and moved. The
/// picture always covers the frame: it is never zoomed out past filling it nor moved past its edges (`clamped`).
nonisolated struct CoverFraming: Codable, Hashable, Sendable {
    static let zoomRange: ClosedRange<Double> = 1...4

    /// 1 fills the frame; 2 shows half of it, twice as big.
    var zoom: Double = 1
    /// Where the picture is moved, -1 to 1 on each side: 0 is centered, 1 shows its right (or bottom) edge.
    var offsetX: Double = 0
    var offsetY: Double = 0

    static let fill = CoverFraming()

    var isUntouched: Bool { self == .fill }

    var clamped: CoverFraming {
        CoverFraming(
            zoom: min(max(zoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound),
            offsetX: min(max(offsetX, -1), 1), offsetY: min(max(offsetY, -1), 1)
        )
    }

    /// Where a picture of `picture` size is drawn to cover `frame` with this framing (from the top left).
    func rect(for picture: CGSize, in frame: CGRect) -> CGRect {
        guard picture.width > 0, picture.height > 0 else { return frame }
        let framing = clamped
        let fill = max(frame.width / picture.width, frame.height / picture.height) * framing.zoom
        let size = CGSize(width: picture.width * fill, height: picture.height * fill)
        let room = CGSize(width: size.width - frame.width, height: size.height - frame.height)
        return CGRect(
            x: frame.minX - room.width / 2 * (1 + framing.offsetX), y: frame.minY - room.height / 2 * (1 + framing.offsetY),
            width: size.width, height: size.height
        )
    }

    /// The framing after a finger moved the picture by `translation` (points) on a frame of `frame` size showing a picture of
    /// `picture` size: the picture follows the finger, as far as it still covers the frame.
    func moved(by translation: CGSize, picture: CGSize, frame: CGSize) -> CoverFraming {
        let shown = rect(for: picture, in: CGRect(origin: .zero, size: frame))
        let room = CGSize(width: shown.width - frame.width, height: shown.height - frame.height)
        var moved = self
        if room.width > 0.5 { moved.offsetX -= 2 * Double(translation.width / room.width) }
        if room.height > 0.5 { moved.offsetY -= 2 * Double(translation.height / room.height) }
        return moved.clamped
    }

    /// The framing zoomed by `factor` (a pinch), keeping where it was moved.
    func zoomed(by factor: Double) -> CoverFraming {
        var zoomed = self
        zoomed.zoom *= factor
        return zoomed.clamped
    }
}
