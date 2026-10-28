//
//  ClipOrientation.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How a clip's picture is reshaped before it is framed (Rotate, Mirror, Crop): turned by quarter turns clockwise, flipped left
/// to right as it then shows, then cut to a box of that. Pure: the compositor (`FramePipeline.oriented`), the preview's mappings
/// (`FramePlacement`) and the tests read the same.
nonisolated struct ClipOrientation: Hashable, Sendable {
    static let identity = ClipOrientation()

    var quarterTurns = 0
    var isMirrored = false
    /// The box kept, fractions of the turned and mirrored picture from its top left; nil keeps all of it.
    var crop: CGRect?

    init(quarterTurns: Int = 0, isMirrored: Bool = false, crop: CGRect? = nil) {
        self.quarterTurns = (quarterTurns % 4 + 4) % 4
        self.isMirrored = isMirrored
        self.crop = crop
    }

    var isIdentity: Bool { quarterTurns == 0 && !isMirrored && crop == nil }

    /// Whether it lies on its side: its width and height swap.
    var turnsSideways: Bool { quarterTurns % 2 == 1 }

    /// The picture's size once turned, before the crop.
    func turnedSize(of size: CGSize) -> CGSize {
        turnsSideways ? CGSize(width: size.height, height: size.width) : size
    }

    /// The size of a picture of `size` once reshaped: turned, then cut to the crop.
    func size(of size: CGSize) -> CGSize {
        let turned = turnedSize(of: size)
        guard let crop else { return turned }
        return CGSize(width: (turned.width * crop.width).rounded(), height: (turned.height * crop.height).rounded())
    }

    /// Where `point` of the upright picture (fractions, from the top left) shows in the reshaped one.
    func shownPoint(_ point: CGPoint) -> CGPoint {
        var x = point.x, y = point.y
        // A quarter turn clockwise takes the top left corner to the top right.
        for _ in 0..<quarterTurns { (x, y) = (1 - y, x) }
        if isMirrored { x = 1 - x }
        if let crop, crop.width > 0, crop.height > 0 {
            x = (x - crop.minX) / crop.width
            y = (y - crop.minY) / crop.height
        }
        return CGPoint(x: x, y: y)
    }

    /// The point of the upright picture shown at `point` of the reshaped one.
    func uprightPoint(_ point: CGPoint) -> CGPoint {
        var x = point.x, y = point.y
        if let crop {
            x = crop.minX + x * crop.width
            y = crop.minY + y * crop.height
        }
        if isMirrored { x = 1 - x }
        for _ in 0..<quarterTurns { (x, y) = (y, 1 - x) }
        return CGPoint(x: x, y: y)
    }

    /// The crop as a box of the upright picture (fractions from its top left): what it keeps of the frame as filmed.
    var uprightCrop: CGRect? {
        guard let crop else { return nil }
        let turned = ClipOrientation(quarterTurns: quarterTurns, isMirrored: isMirrored)
        let first = turned.uprightPoint(CGPoint(x: crop.minX, y: crop.minY))
        let second = turned.uprightPoint(CGPoint(x: crop.maxX, y: crop.maxY))
        return CGRect(x: min(first.x, second.x), y: min(first.y, second.y), width: abs(second.x - first.x), height: abs(second.y - first.y))
    }

    /// `box` of the upright picture (fractions from its top left) in the reshaped one; nil when none of it shows.
    func shownRect(_ box: CGRect) -> CGRect? {
        shownBox(NormalizedBox(x: box.minX, y: box.minY, width: box.width, height: box.height))
            .map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
    }

    /// `box` of the upright picture in the reshaped one (its corners carried over); nil when none of it shows.
    func shownBox(_ box: NormalizedBox) -> NormalizedBox? {
        let first = shownPoint(CGPoint(x: box.x, y: box.y))
        let second = shownPoint(CGPoint(x: box.x + box.width, y: box.y + box.height))
        let left = max(0, min(first.x, second.x)), right = min(1, max(first.x, second.x))
        let top = max(0, min(first.y, second.y)), bottom = min(1, max(first.y, second.y))
        guard right > left, bottom > top else { return nil }
        return NormalizedBox(x: left, y: top, width: right - left, height: bottom - top)
    }
}

nonisolated extension EditSegment {
    /// Rotate, Mirror and Crop of the clip, as the picture is reshaped.
    var orientation: ClipOrientation {
        ClipOrientation(quarterTurns: quarterTurns, isMirrored: isMirrored, crop: crop.flatMap { $0.isWhole ? nil : $0.rect })
    }

    /// Whether it has a way in or out (Animation).
    var animates: Bool { animationIn != nil || animationOut != nil }
}
