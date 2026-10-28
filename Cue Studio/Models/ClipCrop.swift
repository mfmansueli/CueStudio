//
//  ClipCrop.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Crop: the part of a clip's picture (turned and mirrored as the clip says) that fills the frame, as fractions of that picture
/// from its top left, and the shape the box keeps while it is dragged (nil: any shape).
nonisolated struct ClipCrop: Codable, Hashable, Sendable {
    /// The narrowest a side can be, as a fraction of the picture's.
    static let smallestSide: Double = 0.1

    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var ratio: AspectRatio?

    init(_ rect: CGRect, ratio: AspectRatio? = nil) {
        x = Double(rect.minX)
        y = Double(rect.minY)
        width = Double(rect.width)
        height = Double(rect.height)
        self.ratio = ratio
    }

    /// The box as a rect of the unit square, kept inside the picture and never thinner than `smallestSide`.
    var rect: CGRect {
        let width = min(max(width.isFinite ? width : 1, Self.smallestSide), 1)
        let height = min(max(height.isFinite ? height : 1, Self.smallestSide), 1)
        let x = min(max(x.isFinite ? x : 0, 0), 1 - width)
        let y = min(max(y.isFinite ? y : 0, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// It takes the whole picture: nothing to crop.
    var isWhole: Bool {
        let rect = rect
        return rect.width > 0.999 && rect.height > 0.999
    }

    /// The box moved by `offset` (fractions of the picture), never past its edges.
    func moved(by offset: CGSize) -> ClipCrop {
        let rect = rect
        let x = min(max(rect.minX + offset.width, 0), 1 - rect.width)
        let y = min(max(rect.minY + offset.height, 0), 1 - rect.height)
        return ClipCrop(CGRect(x: x, y: y, width: rect.width, height: rect.height), ratio: ratio)
    }

    /// The box with `corner` pulled to `point` (fractions of the picture) and the opposite corner still: inside the picture,
    /// never thinner than `smallestSide`, and of its `ratio` when it has one, on a picture `aspect` wide over tall.
    func pulling(_ corner: ClipCropCorner, to point: CGPoint, aspect: Double) -> ClipCrop {
        let rect = rect
        let anchor = CGPoint(x: corner.direction.x < 0 ? rect.maxX : rect.minX, y: corner.direction.y < 0 ? rect.maxY : rect.minY)
        // The room from the still corner to the picture's edge, on the side the corner is pulled to.
        let roomX = corner.direction.x < 0 ? anchor.x : 1 - anchor.x
        let roomY = corner.direction.y < 0 ? anchor.y : 1 - anchor.y
        let smallest = CGFloat(Self.smallestSide)
        var width = min(max((point.x - anchor.x) * corner.direction.x, smallest), roomX)
        var height = min(max((point.y - anchor.y) * corner.direction.y, smallest), roomY)
        if let ratio, aspect > 0 {
            // Its fractions of the picture's height per fraction of its width, at that shape.
            let tall = CGFloat(aspect / ratio.widthOverHeight)
            width = max(width, height / tall)
            height = width * tall
            let fit = min(1, roomX / width, roomY / height)
            width *= fit
            height *= fit
        }
        let x = corner.direction.x < 0 ? anchor.x - width : anchor.x
        let y = corner.direction.y < 0 ? anchor.y - height : anchor.y
        return ClipCrop(CGRect(x: x, y: y, width: width, height: height), ratio: ratio)
    }

    /// The same part of the picture once it is flipped left to right (Mirror).
    var mirrored: ClipCrop {
        let rect = rect
        return ClipCrop(CGRect(x: 1 - rect.maxX, y: rect.minY, width: rect.width, height: rect.height), ratio: ratio)
    }

    /// The largest box of `ratio` (whole picture for nil) in the middle of a picture `size` big.
    static func centered(_ ratio: AspectRatio?, in size: CGSize) -> ClipCrop {
        guard let ratio, size.width > 0, size.height > 0 else { return ClipCrop(CGRect(x: 0, y: 0, width: 1, height: 1), ratio: ratio) }
        let picture = Double(size.width / size.height)
        // Fractions of the picture's sides: as wide as it can be at that shape.
        let width = min(1, ratio.widthOverHeight / picture)
        let height = min(1, picture / ratio.widthOverHeight)
        return ClipCrop(CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height), ratio: ratio)
    }
}
