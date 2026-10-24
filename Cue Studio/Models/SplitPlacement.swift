//
//  SplitPlacement.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where the areas of a split screen are on a frame, and how a picture sits in its area. Pure, so the compositor, the
/// preview's handles and the tests use the same numbers.
nonisolated enum SplitPlacement {
    /// The two areas on a frame, from the top left, and the seam's line when the layout shows it.
    struct Areas: Equatable, Sendable {
        var main: CGRect
        var support: CGRect
        var divider: CGRect?

        func rect(of area: SplitArea) -> CGRect {
            area == .main ? main : support
        }
    }

    /// How a picture sits in an area: its scale, where its top left corner lands (area coordinates, from the area's top left;
    /// negative where it spills over), and which point of it ends up in the middle (as far as it could go).
    struct Placement: Equatable, Sendable {
        var scale: CGFloat
        var origin: CGPoint
        var size: CGSize
        var center: OverlayPoint
    }

    /// The seam's line, as a share of the frame's short side, never thinner than 2 pixels.
    static let dividerShare: CGFloat = 0.004

    /// The areas of `layout` on a frame of `size`, on whole pixels so they meet without a gap.
    static func areas(_ layout: SplitLayout, in size: CGSize) -> Areas {
        let stacked = layout.arrangement == .stacked
        let length = stacked ? size.height : size.width
        let cut = (length * CGFloat(layout.firstShare)).rounded()
        let first = stacked
            ? CGRect(x: 0, y: 0, width: size.width, height: cut)
            : CGRect(x: 0, y: 0, width: cut, height: size.height)
        let second = stacked
            ? CGRect(x: 0, y: cut, width: size.width, height: max(0, size.height - cut))
            : CGRect(x: cut, y: 0, width: max(0, size.width - cut), height: size.height)
        var areas = layout.first == .main
            ? Areas(main: first, support: second, divider: nil)
            : Areas(main: second, support: first, divider: nil)
        if layout.showsDivider {
            let thickness = max(2, (min(size.width, size.height) * dividerShare).rounded())
            areas.divider = stacked
                ? CGRect(x: 0, y: cut - (thickness / 2).rounded(.down), width: size.width, height: thickness)
                : CGRect(x: cut - (thickness / 2).rounded(.down), y: 0, width: thickness, height: size.height)
        }
        return areas
    }

    /// Where the seam is, as a fraction of the frame from the top (stacked) or the left (side by side).
    static func seam(_ layout: SplitLayout) -> Double {
        layout.firstShare
    }

    /// How a picture of `content` size sits in an area of `area` size as `framing` says: Fill covers the area, Fit shows it
    /// whole, both zoomed in from there; then moved so the framing's center is in the middle, as far as the picture reaches
    /// (a picture larger than the area never leaves an empty edge; one smaller stays centered across that side).
    static func place(_ content: CGSize, in area: CGSize, framing: AreaFraming) -> Placement {
        guard content.width > 0, content.height > 0, area.width > 0, area.height > 0 else {
            return Placement(scale: 1, origin: .zero, size: content, center: .center)
        }
        let fill = max(area.width / content.width, area.height / content.height)
        let fit = min(area.width / content.width, area.height / content.height)
        let scale = (framing.fit == .fill ? fill : fit) * CGFloat(framing.clampedZoom)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        let wanted = framing.clampedCenter
        func axis(_ length: CGFloat, room: CGFloat, center: Double) -> CGFloat {
            guard length > room + 0.000_1 else { return (room - length) / 2 }
            return min(0, max(room - length, room / 2 - CGFloat(center) * length))
        }
        let origin = CGPoint(x: axis(size.width, room: area.width, center: wanted.x), y: axis(size.height, room: area.height, center: wanted.y))
        let center = OverlayPoint(x: Double((area.width / 2 - origin.x) / size.width), y: Double((area.height / 2 - origin.y) / size.height))
        return Placement(scale: scale, origin: origin, size: size, center: center)
    }

    /// `framing` with its center moved by a drag of `translation` on an area of `area` size (the picture follows the finger),
    /// kept where the picture still reaches.
    static func dragged(_ framing: AreaFraming, content: CGSize, area: CGSize, by translation: CGSize) -> AreaFraming {
        let placed = place(content, in: area, framing: framing)
        guard placed.size.width > 0, placed.size.height > 0 else { return framing }
        var moved = framing
        moved.center = OverlayPoint(
            x: placed.center.x - Double(translation.width / placed.size.width),
            y: placed.center.y - Double(translation.height / placed.size.height)
        )
        moved.center = place(content, in: area, framing: moved).center
        return moved
    }

    /// How far a drag can still go before the picture's edge shows, per side (positive: room left), for the rubber band.
    static func overshoot(_ framing: AreaFraming, content: CGSize, area: CGSize, by translation: CGSize) -> CGSize {
        let placed = place(content, in: area, framing: framing)
        func axis(_ origin: CGFloat, _ length: CGFloat, _ room: CGFloat, _ move: CGFloat) -> CGFloat {
            guard length > room + 0.000_1 else { return move }
            let moved = origin + move
            if moved > 0 { return moved }
            if moved < room - length { return moved - (room - length) }
            return 0
        }
        return CGSize(
            width: axis(placed.origin.x, placed.size.width, area.width, translation.width),
            height: axis(placed.origin.y, placed.size.height, area.height, translation.height)
        )
    }

    /// The framing that shows a face found at `face` (a box on the picture, fractions from its top left) well in an area:
    /// across, centered on it; up and down, the eyes about a third down the area, the way talking heads are framed. Without a
    /// face, the picture's middle.
    static func framing(showing face: CGRect?, content: CGSize, area: CGSize) -> AreaFraming {
        guard let face, face.width > 0, face.height > 0 else { return AreaFraming() }
        var framing = AreaFraming()
        let placed = place(content, in: area, framing: framing)
        guard placed.size.height > 0 else { return framing }
        // The eyes sit about 40% down the face box; they go a third down the area.
        let eyes = Double(face.minY + face.height * 0.4)
        let shift = Double(area.height / placed.size.height) * (0.5 - 1.0 / 3.0)
        framing.center = OverlayPoint(x: Double(face.midX), y: eyes + shift)
        framing.center = place(content, in: area, framing: framing).center
        return framing
    }
}
