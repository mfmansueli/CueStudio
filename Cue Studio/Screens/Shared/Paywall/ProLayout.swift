//
//  ProLayout.swift
//  Cue Studio
//

import CoreGraphics

/// The Pro screen's measures for this iPhone, as the owner's canvas draws them (30/10/2026: the galaxy and the rest grow on the bigger iPhones,
/// and everything fits without scrolling): the 15 Pro's, the Pro Max's, and in between they follow the width; a short screen (the SE's 667 pt)
/// takes the SE's, a little smaller everywhere. The calm Pro has a smaller galaxy, so its words start higher. Where the galaxy and the words
/// sit is measured from the top of the screen.
nonisolated struct ProLayout: Equatable {
    var galaxyRadius: CGFloat
    var galaxyY: CGFloat
    var contentY: CGFloat
    /// Between the line under the title and the two highlights, the highlights' height, the gap to the list and each line of it.
    var cardsGap: CGFloat
    var cardHeight: CGFloat
    var listGap: CGFloat
    var rowHeight: CGFloat
    /// Above the plans, and their height.
    var footerTop: CGFloat
    var planHeight: CGFloat
    var buttonGap: CGFloat
    var fineGap: CGFloat
    /// The SE: the words a size down.
    var isCompact = false

    static let regular = ProLayout(
        galaxyRadius: 115, galaxyY: 148, contentY: 236, cardsGap: 16, cardHeight: 88, listGap: 12, rowHeight: 26, footerTop: 12, planHeight: 72,
        buttonGap: 14, fineGap: 12
    )
    static let large = ProLayout(
        galaxyRadius: 130, galaxyY: 174, contentY: 276, cardsGap: 20, cardHeight: 100, listGap: 14, rowHeight: 32, footerTop: 14, planHeight: 78,
        buttonGap: 16, fineGap: 12
    )
    static let compact = ProLayout(
        galaxyRadius: 90, galaxyY: 92, contentY: 166, cardsGap: 12, cardHeight: 64, listGap: 8, rowHeight: 23, footerTop: 10, planHeight: 62,
        buttonGap: 12, fineGap: 10, isCompact: true
    )

    /// The measures for a screen of `size`; `calm` for the calm Pro (from an export or Ultra AI).
    init(screen size: CGSize, calm: Bool) {
        if size.height > 0, size.height < 740 {
            self = .compact
        } else {
            let progress = min(1, max(0, (size.width - 393) / (440 - 393)))
            self = Self.regular.mixed(with: .large, progress: progress)
        }
        guard calm else { return }
        // The canvas's calm Pro: a galaxy of 210 pt instead of 230, 12 pt higher, and the words 26 pt higher.
        galaxyRadius *= 0.913
        galaxyY -= 12
        contentY -= 26
    }

    private init(
        galaxyRadius: CGFloat, galaxyY: CGFloat, contentY: CGFloat, cardsGap: CGFloat, cardHeight: CGFloat, listGap: CGFloat, rowHeight: CGFloat,
        footerTop: CGFloat, planHeight: CGFloat, buttonGap: CGFloat, fineGap: CGFloat, isCompact: Bool = false
    ) {
        self.galaxyRadius = galaxyRadius
        self.galaxyY = galaxyY
        self.contentY = contentY
        self.cardsGap = cardsGap
        self.cardHeight = cardHeight
        self.listGap = listGap
        self.rowHeight = rowHeight
        self.footerTop = footerTop
        self.planHeight = planHeight
        self.buttonGap = buttonGap
        self.fineGap = fineGap
        self.isCompact = isCompact
    }

    private func mixed(with other: ProLayout, progress: CGFloat) -> ProLayout {
        func mix(_ path: KeyPath<ProLayout, CGFloat>) -> CGFloat { self[keyPath: path] + (other[keyPath: path] - self[keyPath: path]) * progress }
        return ProLayout(
            galaxyRadius: mix(\.galaxyRadius), galaxyY: mix(\.galaxyY), contentY: mix(\.contentY), cardsGap: mix(\.cardsGap),
            cardHeight: mix(\.cardHeight), listGap: mix(\.listGap), rowHeight: mix(\.rowHeight), footerTop: mix(\.footerTop),
            planHeight: mix(\.planHeight), buttonGap: mix(\.buttonGap), fineGap: mix(\.fineGap)
        )
    }
}
