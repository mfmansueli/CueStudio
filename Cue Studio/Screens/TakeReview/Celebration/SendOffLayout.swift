//
//  SendOffLayout.swift
//  Cue Studio
//

import CoreGraphics

/// Where the send-off (8.2) puts things on the board's 390 × 844 frame (`8.2_1-network`, `8.2_3-networks`): YOU in the middle of two flat
/// orbits, each network's planet at its own fixed spot round it, the card below the map, and the new star beside YOU.
nonisolated enum SendOffLayout {
    /// The frame everything is placed on.
    static let board = CGSize(width: 390, height: 844)
    /// The map's part of the frame (the card sits at its foot).
    static let mapHeight: CGFloat = 580

    static let you = CGPoint(x: 195, y: 300)
    static let youDiameter: CGFloat = 56
    /// The two orbits: their width, flattened to 32% and turned −9°.
    static let orbitWidths: [CGFloat] = [316, 220]
    static let orbitFlatness: CGFloat = 0.32
    static let orbitTurn = -9.0

    /// The video's card: 54 × 96 pt under the map, 12 pt radius.
    static let card = CGRect(x: 168, y: 470, width: 54, height: 96)
    static let cardRadius: CGFloat = 12
    /// The star that lights beside YOU.
    static let newStar = CGPoint(x: 236, y: 262)

    /// The text block starts here, and the buttons stand 34 pt over the bottom.
    static let textsTop: CGFloat = 582
    static let buttonsBottom: CGFloat = 34

    /// A network's planet, at its own spot: a planet never moves to make room for another.
    static func center(of platform: Platform) -> CGPoint {
        switch platform {
        case .tiktok: CGPoint(x: 328.09, y: 248.50)
        case .reels: CGPoint(x: 52.51, y: 292.15)
        case .shorts: CGPoint(x: 61.91, y: 351.50)
        case .youtube: CGPoint(x: 163.37, y: 240.84)
        case .linkedin: CGPoint(x: 332.65, y: 312.54)
        case .stories: CGPoint(x: 188.64, y: 365.45)
        }
    }

    /// The planets' diameters, biggest to smallest by the videos each network has this year (a tie keeps the board's order).
    static let diameters: [CGFloat] = [20, 18, 17, 16, 14, 12]

    static func diameter(of platform: Platform, counts: [Platform: Int]) -> CGFloat {
        let ranked = Platform.allCases.enumerated().sorted { left, right in
            let (a, b) = (counts[left.element] ?? 0, counts[right.element] ?? 0)
            return a != b ? a > b : left.offset < right.offset
        }
        let rank = ranked.firstIndex { $0.element == platform } ?? diameters.count - 1
        return diameters[min(rank, diameters.count - 1)]
    }

    /// Where the "+1" of the `index`-th network sits: the first one centred over its planet, the next above it, to the left, and the one after
    /// below the planet's name, so the three never touch. Returns the label's left edge (or its centre) and its top.
    struct PlusSpot: Equatable {
        let point: CGPoint
        let isCentred: Bool
    }

    static func plusSpot(index: Int, center: CGPoint, diameter: CGFloat) -> PlusSpot {
        let radius = diameter / 2
        switch index {
        case 0: return PlusSpot(point: CGPoint(x: center.x, y: center.y - radius - 24), isCentred: true)
        case 1: return PlusSpot(point: CGPoint(x: center.x - 17, y: center.y - radius - 24), isCentred: false)
        default:
            let above = index.isMultiple(of: 2) == false
            return PlusSpot(point: CGPoint(x: center.x - 17, y: above ? center.y - radius - 24 : center.y + radius + 23), isCentred: false)
        }
    }

    /// The route of a star from the card to a planet: an arc that bows up and out, the way a thrown ribbon would.
    static func arc(to end: CGPoint) -> (start: CGPoint, control: CGPoint, end: CGPoint) {
        let start = CGPoint(x: card.midX, y: card.midY)
        let chord = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let length = max(hypot(chord.x, chord.y), 1)
        var normal = CGPoint(x: -chord.y / length, y: chord.x / length)
        if normal.y > 0 { normal = CGPoint(x: -normal.x, y: -normal.y) }
        let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        return (start, CGPoint(x: middle.x + normal.x * 0.28 * length, y: middle.y + normal.y * 0.28 * length), end)
    }

    /// A point on that arc, `progress` of the way (0...1).
    static func point(on route: (start: CGPoint, control: CGPoint, end: CGPoint), at progress: Double) -> CGPoint {
        let u = min(1, max(0, progress)), v = 1 - u
        return CGPoint(
            x: v * v * route.start.x + 2 * v * u * route.control.x + u * u * route.end.x,
            y: v * v * route.start.y + 2 * v * u * route.control.y + u * u * route.end.y
        )
    }
}
