//
//  FilterFanPlan.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where each chip of a `FilterFan` sits and when it moves, without a screen (the owner's folding filter row, 05/11/2026).
///
/// Closed, only the chosen chip shows at the start of the row, with a dot for each hidden option after it (up to `peekLimit`); the hidden
/// chips wait behind it, centred on it and a little smaller, so they come out of it. Open, every chip sits in its own place, `spacing`
/// apart, in an order that never changes, so the hand learns where each one is. Unfolding, the chips leave the nearest first; folding,
/// the farthest leave first, so all of them arrive home together.
nonisolated struct FilterFanPlan: Equatable {
    /// Each chip's width, in the options' order.
    var widths: [CGFloat]
    /// The chosen chip.
    var selected: Int
    var isOpen: Bool
    var spacing: CGFloat = 8

    struct Placement: Equatable {
        /// From the start of the fan (the trailing edge in a right-to-left language).
        var x: CGFloat
        var scale: CGFloat
        var opacity: Double
        /// Tappable and read by VoiceOver: false while it waits behind the chosen one.
        var isShown: Bool
        /// The chosen chip on top, then the nearest ones.
        var zIndex: Double
    }

    /// What changes the row, for the animation: the state, and which chip is chosen.
    struct Key: Hashable {
        var isOpen: Bool
        var selected: Int
    }

    static let peekLimit = 4
    static let peekGap: CGFloat = 7
    static let peekDot: CGFloat = 7
    /// Between two dots: apart, not tucked (the owner, 05/11/2026).
    static let peekSpacing: CGFloat = 3
    /// How small a chip is while it waits behind the chosen one.
    static let hiddenScale: CGFloat = 0.82
    /// Between two chips leaving the chosen one, the nearest first.
    static let unfoldStagger: TimeInterval = 0.028
    /// Between two chips starting home, the farthest first.
    static let foldStagger: TimeInterval = 0.022
    /// From a chip starting to move to the moment it comes free of the chosen one (the neck of liquid breaks).
    static let releaseLag: TimeInterval = 0.06
    /// From a chip starting home to the moment it is in place behind the chosen one (`FilterFanMotion.fold`).
    static let foldTravel: TimeInterval = 0.3

    /// The row folds with two options or more, the same on every screen (the owner, 05/11/2026: Takes with All and one network folds like
    /// Scripts), and never under VoiceOver or Switch Control: a dot that hints at a hidden chip says nothing to them.
    static func folds(optionCount: Int, assistiveTechnology: Bool) -> Bool {
        optionCount >= 2 && !assistiveTechnology
    }

    /// The widest a chip may be: the row less its gutters, what comes before the fan and the dots (`hasPeek`: a row that never folds has
    /// none), so a long folder name is cut with "…" only past that. Never under 80 pt.
    static func maxChipWidth(rowWidth: CGFloat, gutter: CGFloat, leadingWidth: CGFloat, hasPeek: Bool = true) -> CGFloat {
        let dots = hasPeek ? peekGap + peekWidth(count: peekLimit) : 0
        return max(80, rowWidth - 2 * gutter - leadingWidth - dots)
    }

    static func peekWidth(count: Int) -> CGFloat {
        count == 0 ? 0 : CGFloat(count) * peekDot + CGFloat(count - 1) * peekSpacing
    }

    var key: Key { Key(isOpen: isOpen, selected: selected) }

    private var selectedWidth: CGFloat { widths.indices.contains(selected) ? widths[selected] : 0 }

    /// Each chip's place in the open row.
    var slots: [CGFloat] {
        var x: CGFloat = 0
        return widths.map { width in
            defer { x += width + spacing }
            return x
        }
    }

    /// The open row, from the first chip to the end of the last.
    var openWidth: CGFloat {
        widths.isEmpty ? 0 : widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
    }

    var peekCount: Int { isOpen ? 0 : min(Self.peekLimit, max(0, widths.count - 1)) }

    /// The hidden options the dots stand for, in order.
    var peekIndices: [Int] {
        Array(widths.indices.filter { $0 != selected }.prefix(Self.peekLimit))
    }

    /// Where the dots start: just after the chosen chip (tucked a little under it while the row is open, where they are hidden).
    var peekX: CGFloat { selectedWidth + (isOpen ? -4 : Self.peekGap) }

    func placement(at index: Int) -> Placement {
        let distance = Double(abs(index - selected))
        let zIndex = index == selected ? 100 : 50 - distance
        if isOpen {
            return Placement(x: slots[index], scale: 1, opacity: 1, isShown: true, zIndex: zIndex)
        }
        if index == selected {
            return Placement(x: 0, scale: 1, opacity: 1, isShown: true, zIndex: zIndex)
        }
        let centred = (selectedWidth - widths[index]) / 2
        return Placement(x: centred, scale: Self.hiddenScale, opacity: 0, isShown: false, zIndex: zIndex)
    }

    private var farthest: Int {
        widths.indices.map { abs($0 - selected) }.max() ?? 0
    }

    /// When the chip starts to move, from the touch.
    func delay(at index: Int) -> TimeInterval {
        let distance = abs(index - selected)
        return isOpen ? Double(distance) * Self.unfoldStagger : Double(farthest - distance) * Self.foldStagger
    }

    /// Unfolding: when each hidden chip comes free of the chosen one, the nearest first (where the light ticks go).
    var releaseTimes: [TimeInterval] {
        widths.indices.filter { $0 != selected }
            .map { Double(abs($0 - selected)) * Self.unfoldStagger + Self.releaseLag }
            .sorted()
    }

    /// Folding: when the last chip is home behind the chosen one (where the firm tap goes).
    var foldLanding: TimeInterval {
        Double(farthest) * Self.foldStagger + Self.foldTravel
    }
}
