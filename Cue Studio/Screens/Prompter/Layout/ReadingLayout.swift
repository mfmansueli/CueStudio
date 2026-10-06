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
    /// While a take records the box shrinks: 10 pt in on each side and 16% shorter.
    static let recordingInset: CGFloat = 10
    static let recordingHeightFactor: CGFloat = 0.84

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
        readingWidth: Double,
        isRecording: Bool = false
    ) {
        lensY = metrics.lensY
        screenWidth = metrics.screen.width
        let topLimit = Self.clamp(metrics.topBarBottom + Self.topBarGap, to: 0...max(0, metrics.screen.height))
        let bottomLimit = max(topLimit, min(metrics.toolbarTop, metrics.screen.height))
        let availableHeight = bottomLimit - topLimit
        // Short layouts keep the window visible instead of inventing space below the screen.
        let minimumLead = min(Self.minimumLead, availableHeight * Self.leadFraction)
        let minimumBelow = min(Self.minimumBelow, availableHeight - minimumLead)
        lineRange = (topLimit + minimumLead)...(bottomLimit - minimumBelow)

        let recommended = isFrontCamera
            ? metrics.lensY + Self.recommendedFrontOffset
            : frameRect.minY + frameRect.height * Self.rearFrameFraction
        isRecommended = lineOffset == nil
        let requestedLine = lineOffset.map { metrics.lensY + CGFloat($0) } ?? recommended
        lineY = Self.clamp(requestedLine.rounded(), to: lineRange)

        // Recording puts the focus on the words: the box is a little narrower and 16% shorter (v29 · 5.2).
        let chosenHeight = CGFloat(Self.clamp(windowHeight, to: PrompterSettings.textWindowHeightRange))
        let height = min(availableHeight, isRecording ? (chosenHeight * Self.recordingHeightFactor).rounded() : chosenHeight)
        let lead = max(minimumLead, min(height * Self.leadFraction, lineY - topLimit))
        let top = lineY - lead
        let widthFraction = Self.clamp(readingWidth, to: PrompterSettings.readingWidthRange)
        let width = max(0, (metrics.screen.width * widthFraction).rounded() - (isRecording ? Self.recordingInset * 2 : 0))
        windowRect = CGRect(
            x: ((metrics.screen.width - width) / 2).rounded(),
            y: top,
            width: width,
            height: min(height, bottomLimit - top)
        )
    }

    /// The practice run's layout (1.6): a box of 238 pt, 12 pt in from the sides and 100 pt from the top, with the line 128 pt down it. It does
    /// not follow the creator's own box and line: the practice is the same for everyone, and nothing of it is kept.
    init(practiceScreen screen: CGSize) {
        let box = CGRect(x: 12, y: 100, width: max(0, screen.width - 24), height: 238)
        lensY = 0
        screenWidth = screen.width
        windowRect = box
        lineY = box.minY + 128
        lineRange = lineY...lineY
        isRecommended = true
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
