//
//  ReadingLayout.swift
//  Cue Studio
//

import CoreGraphics

/// Where the Selfie reading line and text window sit. They are two layers with their own state —
/// the line stays put and the text scrolls past it; the window only follows the line — tied by
/// one layout rule: the line sits about a quarter of the way down the window, so the next
/// sentences show below it. Where Cue places them (the creator hasn't moved the line), the line sits just under the lens and the window
/// starts right under the top bar's buttons, with the front camera or the rear one (owner, 11/11/2026).
nonisolated struct ReadingLayout: Equatable, Sendable {
    /// Recommended distance from the front camera to the line: just under the lens, so the eyes
    /// stay close to the viewer. The rear camera reads at the same place, so the window stays under the top bar.
    static let recommendedFrontOffset: CGFloat = 118
    /// The line sits this far down the window, as a fraction of its height…
    static let leadFraction: CGFloat = 0.25
    /// Where Cue places the line, the window starts under the top bar and the line sits at most this far down it.
    static let recommendedLeadLimit: CGFloat = 0.5
    /// …but never closer to the window's top than this.
    static let minimumLead: CGFloat = 18
    /// Room kept under a line dragged low, for the next sentences.
    static let minimumBelow: CGFloat = 88
    /// Space between the top bar's buttons and the window.
    static let topBarGap: CGFloat = 8
    /// One tap on ↑ or ↓ in Display.
    static let nudge: CGFloat = 8
    /// While a take records the box shrinks: 10 pt in on each side and 16% shorter, from the bottom (its top and the line stay put).
    static let recordingInset: CGFloat = 10
    static let recordingHeightFactor: CGFloat = 0.84
    /// Room between the text window and a card above the toolbar (`SelfieScreenMetrics.cardTop`).
    static let cardGap: CGFloat = 8

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
        lineOffset: Double?,
        windowHeight: Double,
        readingWidth: Double,
        isRecording: Bool = false
    ) {
        lensY = metrics.lensY
        screenWidth = metrics.screen.width
        let topLimit = Self.clamp(metrics.topControlsBottom + Self.topBarGap, to: 0...max(0, metrics.screen.height))
        let bottomLimit = max(topLimit, min(metrics.toolbarTop, metrics.cardTop ?? metrics.toolbarTop, metrics.screen.height))
        let availableHeight = bottomLimit - topLimit
        // Short layouts keep the window visible instead of inventing space below the screen.
        let minimumLead = min(Self.minimumLead, availableHeight * Self.leadFraction)
        let minimumBelow = min(Self.minimumBelow, availableHeight - minimumLead)
        lineRange = (topLimit + minimumLead)...(bottomLimit - minimumBelow)

        isRecommended = lineOffset == nil
        let requestedLine = lineOffset.map { metrics.lensY + CGFloat($0) } ?? metrics.lensY + Self.recommendedFrontOffset
        lineY = Self.clamp(requestedLine.rounded(), to: lineRange)

        let chosenHeight = min(availableHeight, CGFloat(Self.clamp(windowHeight, to: PrompterSettings.textWindowHeightRange)))
        // Where Cue places the line, the window hugs the top bar (the line may sit deeper than a quarter, up to half); a line the creator
        // moved keeps a quarter of the window above it, and the window follows it.
        let leadLimit = chosenHeight * (isRecommended ? Self.recommendedLeadLimit : Self.leadFraction)
        let lead = max(minimumLead, min(leadLimit, lineY - topLimit))
        let top = lineY - lead
        // Recording puts the focus on the words: the box is a little narrower and 16% shorter (v29 · 5.2), from the bottom.
        let height = isRecording ? (chosenHeight * Self.recordingHeightFactor).rounded() : chosenHeight
        let widthFraction = Self.clamp(readingWidth, to: PrompterSettings.readingWidthRange)
        let width = max(0, (metrics.screen.width * widthFraction).rounded() - (isRecording ? Self.recordingInset * 2 : 0))
        windowRect = CGRect(
            x: ((metrics.screen.width - width) / 2).rounded(),
            y: top,
            width: width,
            height: min(height, bottomLimit - top)
        )
    }

    /// The practice run's layout (1.6): a box 12 pt in from the sides and 100 pt from the top, with the line 128 pt down it. The box is 310 pt
    /// tall (the board's 238 and 30% more below the line, the owner's call), less on a short screen so the card and the buttons still fit
    /// under it, never less than the board's. It does not follow the creator's own box and line: the practice is the same for everyone, and
    /// nothing of it is kept.
    init(practiceScreen screen: CGSize) {
        let height = min(max(screen.height - 542, 238), 310)
        let box = CGRect(x: 12, y: 100, width: max(0, screen.width - 24), height: height)
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
        let inset = Self.lineInset(textLeading: windowRect.minX)
        return inset...max(inset, screenWidth - inset)
    }

    /// How far the reading line stays from the screen's edge: 16 pt past where the text starts, and never closer than 8 pt. Selfie's line
    /// and Studio's follow this one rule, so they have the same room at their ends.
    static func lineInset(textLeading: CGFloat) -> CGFloat {
        max(8, textLeading - 16)
    }

    private static func clamp<Value: Comparable>(_ value: Value, to range: ClosedRange<Value>) -> Value {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
