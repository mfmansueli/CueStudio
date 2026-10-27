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

    /// Room the badge keeps on each side of its words, and the room it keeps from the tool's edges (so from the next tool).
    static let badgePadding: CGFloat = 3.5
    static let badgeClearance: CGFloat = 1

    /// Whether a badge whose words are `labelWidth` points wide is no wider than a tool `toolWidth` wide, its clearance included.
    static func badgeFits(labelWidth: CGFloat, toolWidth: CGFloat) -> Bool {
        labelWidth + 2 * (badgePadding + badgeClearance) <= toolWidth
    }
}
