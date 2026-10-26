//
//  EditorToolbarFit.swift
//  Cue Studio
//

import CoreGraphics

/// How wide each tool of the toolbar is drawn. As wide as its height class asks (or its label needs) while they all fit; when
/// they would only just overflow, with the last one half hidden under the pinned Delete (the four tools of a picked Blur area on
/// a 6.1" iPhone), each gives up some of its room, never below `minimum` nor its label, so every tool shows whole and nothing
/// scrolls; too many to fit even so, they keep their width and scroll. Pure, so it's tested without a screen.
nonisolated enum EditorToolbarFit {
    /// The widths for tools whose labels are `labels` points wide, in `available` points: `preferred` is the class's width,
    /// `padding` what a tool adds around its label, `breathing` the room a label keeps around it when tools narrow.
    static func widths(
        labels: [CGFloat], preferred: CGFloat, minimum: CGFloat, padding: CGFloat, breathing: CGFloat, available: CGFloat
    ) -> [CGFloat] {
        let natural = labels.map { max(preferred, $0 + padding) }
        guard natural.reduce(0, +) > available else { return natural }
        let least = labels.map { max(minimum, $0 + breathing) }
        let leastTotal = least.reduce(0, +), naturalTotal = natural.reduce(0, +)
        guard leastTotal <= available, naturalTotal > leastTotal else { return natural }
        // Each gives up the same share of what it could give up.
        let kept = (available - leastTotal) / (naturalTotal - leastTotal)
        return zip(least, natural).map { least, natural in least + (natural - least) * kept }
    }

    /// The same for a bar whose first `count` tools are the picked item's own and the rest the editor's other tools after them:
    /// only the own tools narrow to show whole beside Delete (the others wait past the edge, at their width).
    static func widths(
        labels: [CGFloat], fittingFirst count: Int, preferred: CGFloat, minimum: CGFloat, padding: CGFloat, breathing: CGFloat,
        available: CGFloat
    ) -> [CGFloat] {
        let count = min(max(count, 0), labels.count)
        let own = widths(
            labels: Array(labels.prefix(count)), preferred: preferred, minimum: minimum, padding: padding, breathing: breathing,
            available: available
        )
        return own + labels.dropFirst(count).map { max(preferred, $0 + padding) }
    }

    // MARK: - Scope badge

    /// Room the badge keeps on each side of its words, the ring of the bar's color around it, and the room it keeps from the
    /// tool's edges (so from the next tool's badge).
    static let badgePadding: CGFloat = 3.5
    static let badgeRing: CGFloat = 1
    static let badgeClearance: CGFloat = 1
    /// How much wider than the class's width a tool may draw so its badge shows the long words.
    static let badgeGrowth: CGFloat = 12

    /// The width a badge whose words are `labelWidth` points wide takes over a tool, its clearance included.
    static func badgeRoom(labelWidth: CGFloat) -> CGFloat {
        labelWidth + 2 * (badgePadding + badgeRing + badgeClearance)
    }

    /// Whether a badge whose words are `labelWidth` points wide shows over a tool `toolWidth` wide without reaching its
    /// neighbours.
    static func badgeFits(labelWidth: CGFloat, toolWidth: CGFloat) -> Bool {
        badgeRoom(labelWidth: labelWidth) <= toolWidth
    }

    /// Whether a bar's badges show the long words ("WHOLE VIDEO", `labelWidth` points wide): when every badged tool, at its
    /// width (`toolWidths`) or at most `badgeGrowth` wider than the class's `preferred`, has room for them. One form on the whole
    /// bar, never "WHOLE VIDEO" on one tool and "ALL" on the next.
    static func longBadgeFits(labelWidth: CGFloat, toolWidths: [CGFloat], preferred: CGFloat) -> Bool {
        let room = badgeRoom(labelWidth: labelWidth)
        return toolWidths.allSatisfy { room <= max($0, preferred + badgeGrowth) }
    }
}
