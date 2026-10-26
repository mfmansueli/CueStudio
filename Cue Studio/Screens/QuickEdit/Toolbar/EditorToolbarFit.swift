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
}
