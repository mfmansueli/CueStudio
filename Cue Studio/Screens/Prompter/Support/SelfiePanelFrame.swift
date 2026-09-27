//
//  SelfiePanelFrame.swift
//  Cue Studio
//

import CoreGraphics

/// Where the Selfie script panel sits on screen: the platform's top and height (scaled from the
/// reference screen), centered, as wide as the reading width.
nonisolated enum SelfiePanelFrame {
    /// Space kept between a panel in the letterbox bar and the video below it.
    static let barGap: CGFloat = 8
    /// A panel is never squeezed shorter than this to fit the bar.
    static let minimumHeight: CGFloat = 120

    /// `bottomLimit` keeps a landscape (YouTube) panel inside the black bar above the video: the
    /// camera fills the screen, so the real bar can be shorter than on the design's screen.
    static func frame(
        layout: PrompterPanelLayout,
        readingWidth: Double,
        screen: CGSize,
        reference: CGSize,
        bottomLimit: CGFloat? = nil
    ) -> CGRect {
        var (top, height) = layout.verticalExtent(screenHeight: screen.height, referenceHeight: reference.height)
        if let bottomLimit {
            height = max(minimumHeight, min(height, bottomLimit - barGap - top))
        }
        let widthFraction = min(PrompterPanelLayout.widthRange.upperBound, max(PrompterPanelLayout.widthRange.lowerBound, readingWidth))
        let width = (screen.width * widthFraction).rounded()
        return CGRect(x: ((screen.width - width) / 2).rounded(), y: top, width: width, height: height)
    }
}
