//
//  ReadingLayout.swift
//  Cue Studio
//

import CoreGraphics

/// Where the Selfie reading line and text window sit. They are two layers with their own state —
/// the line stays put and the text scrolls past it; the window only follows the line — tied by
/// one layout rule: the line sits about a quarter of the way down the window, so the next
/// sentences show below it.
nonisolated struct ReadingLayout: Equatable, Sendable {
    /// Recommended distance from the front camera to the line: just under the lens, so the eyes
    /// stay close to the viewer.
    static let recommendedFrontOffset: CGFloat = 118
    /// With a rear camera there is no lens to read under; the line sits 36% down the frame.
    static let rearFrameFraction: CGFloat = 0.36
    /// The line sits this far down the window, as a fraction of its height…
    static let leadFraction: CGFloat = 0.25
    /// …but never closer to the window's top than this.
    static let minimumLead: CGFloat = 18
    /// Room kept under a line dragged low, for the next sentences.
    static let minimumBelow: CGFloat = 88
    /// Space between the top bar and the window.
    static let topBarGap: CGFloat = 8
    /// One tap on ↑ or ↓ in Display.
    static let nudge: CGFloat = 8

    let lensY: CGFloat
    let lineY: CGFloat
    let windowRect: CGRect
    /// Where the line may go on this screen: under the top bar, above the toolbar.
    let lineRange: ClosedRange<CGFloat>
    /// The line is where Cue recommends (the creator hasn't moved it).
    let isRecommended: Bool
    let screenWidth: CGFloat

    init(
        metrics: SelfieScreenMetrics,
        isFrontCamera: Bool,
        frameRect: CGRect,
        lineOffset: Double?,
        windowHeight: Double,
        readingWidth: Double
    ) {
        lensY = metrics.lensY
        screenWidth = metrics.screen.width
        let topLimit = metrics.topBarBottom + Self.topBarGap
        let bottomLimit = max(topLimit + Self.minimumLead + Self.minimumBelow, metrics.toolbarTop)
        lineRange = (topLimit + Self.minimumLead)...(bottomLimit - Self.minimumBelow)

        let recommended = isFrontCamera
            ? metrics.lensY + Self.recommendedFrontOffset
            : frameRect.minY + frameRect.height * Self.rearFrameFraction
        isRecommended = lineOffset == nil
        lineY = Self.clamp(lineOffset.map { metrics.lensY + CGFloat($0) } ?? recommended, to: lineRange).rounded()

        let height = CGFloat(Self.clamp(windowHeight, to: PrompterSettings.textWindowHeightRange))
        let lead = max(Self.minimumLead, min(height * Self.leadFraction, lineY - topLimit))
        let top = lineY - lead
        let widthFraction = Self.clamp(readingWidth, to: PrompterSettings.readingWidthRange)
        let width = (metrics.screen.width * widthFraction).rounded()
        windowRect = CGRect(
            x: ((metrics.screen.width - width) / 2).rounded(),
            y: top,
            width: width,
            height: min(height, bottomLimit - top)
        )
    }

    /// Where the line sits inside the window, from its top: where the current line of text goes.
    var lead: CGFloat { lineY - windowRect.minY }

    /// The line's distance below the lens, as stored in the settings.
    var lineOffset: CGFloat { lineY - lensY }

    /// A line position on this screen, as the distance to store.
    func offset(forLineAt y: CGFloat) -> Double {
        Double(Self.clamp(y, to: lineRange).rounded() - lensY)
    }

    /// The line spans the window and a little more on each side, so it reads as a guide across the text.
    var lineSpan: ClosedRange<CGFloat> {
        let inset = max(8, windowRect.minX - 16)
        return inset...max(inset, screenWidth - inset)
    }

    private static func clamp<Value: Comparable>(_ value: Value, to range: ClosedRange<Value>) -> Value {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
