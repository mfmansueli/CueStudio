//
//  CardRowPosition.swift
//  Cue Studio
//

import SwiftUI

/// Where a row sits in the group card its section makes: a `List` draws one row at a time (and gives a row no way to ask), so each
/// row is told whether it is the first (the top corners), the last (the bottom ones) or in between, to draw its slice of the card
/// and of its shadow (`cardDepth`). A row alone is `.only`.
enum CardRowPosition: Equatable {
    case only, first, middle, last

    init(index: Int, count: Int) {
        switch (index, count) {
        case (_, 1): self = .only
        case (0, _): self = .first
        case (count - 1, _): self = .last
        default: self = .middle
        }
    }

    /// The sides where the group card goes on into the next row: no shadow crosses them (see `cardDepth`).
    var openEdges: Edge.Set {
        switch self {
        case .only: []
        case .first: .bottom
        case .middle: [.top, .bottom]
        case .last: .top
        }
    }

    /// The first row has the card's top corners, the last its bottom ones.
    func cornerRadii(_ radius: CGFloat) -> RectangleCornerRadii {
        let top = (self == .only || self == .first) ? radius : 0
        let bottom = (self == .only || self == .last) ? radius : 0
        return RectangleCornerRadii(topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top)
    }
}
