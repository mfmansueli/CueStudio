//
//  ReadingLinePinch.swift
//  Cue Studio
//

import SwiftUI

/// A pinch on the text box's right edge moves the reading line (v29 · 5.2): fingers apart takes it down, together takes it up, one
/// 100% pinch being 35% of the screen. The line stays between 10% (by the camera) and 50% (the middle) of the height. The thin
/// handle on the line is the other way to move it. Off while a take records, when the line stays put.
struct ReadingLinePinch: View {
    let viewModel: PrompterViewModel
    let layout: ReadingLayout

    /// The edge that listens, in points.
    static let edgeWidth: CGFloat = 56
    /// How far a full pinch (magnification 2) moves the line, as a fraction of the screen's height.
    static let reach: Double = 0.35

    @State private var startFraction: Double?

    var body: some View {
        Color.clear
            .frame(width: Self.edgeWidth, height: layout.windowRect.height)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let base = startFraction ?? viewModel.readingLineFraction
                        startFraction = base
                        viewModel.moveReadingLine(toFraction: Self.fraction(from: base, magnification: value.magnification))
                    }
                    .onEnded { _ in startFraction = nil }
            )
            .position(x: layout.screenWidth - Self.edgeWidth / 2, y: layout.windowRect.midY)
            .accessibilityHidden(true)
    }

    /// Where a pinch of `magnification` takes a line that started at `fraction`, held to 10–50%.
    static func fraction(from fraction: Double, magnification: Double) -> Double {
        let moved = fraction + (magnification - 1) * reach
        return min(PrompterSettings.readingLineRange.upperBound, max(PrompterSettings.readingLineRange.lowerBound, moved))
    }
}
