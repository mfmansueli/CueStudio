//
//  InterfaceTypeTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

/// The interface's type: the board's size at the default text size, grown with Dynamic Type on its text style's curve, and a
/// little smaller or bigger with the iPhone's width.
@MainActor
struct InterfaceTypeTests {
    @Test func atTheDefaultTextSizeEverySizeIsTheBoards() {
        for points in [9.5, 10, 13.5, 15.5, 17, 22, 27, 34, 64] as [CGFloat] {
            #expect(abs(InterfaceType.size(points, for: .large) - points) < 0.01, "\(points) pt")
        }
    }

    @Test func itGrowsWithTheTextSizeAndShrinksBelowIt() {
        let rowTitle: CGFloat = 15.5
        let sizes: [DynamicTypeSize] = [.xSmall, .large, .xxxLarge, .accessibility1, .accessibility5]
        let grown = sizes.map { InterfaceType.size(rowTitle, for: $0) }
        #expect(zip(grown, grown.dropFirst()).allSatisfy { $0 < $1 }, "\(grown)")
        #expect(grown.last ?? 0 > rowTitle * 2, "The largest accessibility size more than doubles a row's title")
    }

    @Test func eachSizeGrowsOnItsTextStylesCurveAsTheSystemsDo() {
        let label = InterfaceType.size(10, for: .accessibility3) / 10
        let body = InterfaceType.size(17, for: .accessibility3) / 17
        let title = InterfaceType.size(27, for: .accessibility3) / 27
        #expect(title < body, "A title grows less than body text")
        #expect(label > body, "A small label grows more than body text, as caption 2 does, so it stays readable")
        // The growth `UIFontMetrics` gives, what `@ScaledMetric` and `Font.custom(_:size:relativeTo:)` use.
        let metrics = UIFontMetrics(forTextStyle: .body)
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)
        #expect(abs(InterfaceType.size(17, relativeTo: .body, for: .accessibility3) - metrics.scaledValue(for: 17, compatibleWith: traits)) < 0.001)
    }

    @Test func eachSizeGrowsOnTheNearestTextStyle() {
        #expect(InterfaceType.style(for: 10) == .caption2)
        #expect(InterfaceType.style(for: 12) == .caption)
        #expect(InterfaceType.style(for: 13.5) == .footnote)
        #expect(InterfaceType.style(for: 15) == .subheadline)
        #expect(InterfaceType.style(for: 16) == .callout)
        #expect(InterfaceType.style(for: 17) == .body)
        #expect(InterfaceType.style(for: 20) == .title3)
        #expect(InterfaceType.style(for: 22) == .title2)
        #expect(InterfaceType.style(for: 28) == .title)
        #expect(InterfaceType.style(for: 34) == .largeTitle)
    }

    @Test func aTextStyleKeepsItsOwnDefaultSize() {
        #expect(InterfaceType.defaultSize(of: .body) == 17)
        #expect(InterfaceType.defaultSize(of: .caption2) == 11)
        #expect(InterfaceType.defaultSize(of: .largeTitle) == 34)
    }

    @Test func theScreensProportionScalesTheBoardsSize() {
        #expect(abs(InterfaceType.size(15, for: .large, proportion: 1.08) - 16.2) < 0.01)
        #expect(abs(InterfaceType.size(15, for: .large, proportion: 0.96) - 14.4) < 0.01)
    }

    @Test func theBoardsWidthsKeepTheBoardsSizesAndTheEndsStop() {
        for width in [390, 393, 402] as [CGFloat] {
            #expect(ScreenProportion.factor(forWidth: width) == 1, "\(width) pt")
        }
        #expect(abs(ScreenProportion.factor(forWidth: 375) - 0.96) < 0.001, "iPhone SE and mini")
        #expect(abs(ScreenProportion.factor(forWidth: 440) - 1.08) < 0.001, "Pro Max")
        #expect(ScreenProportion.factor(forWidth: 420) > 1 && ScreenProportion.factor(forWidth: 420) < 1.08, "Air, in between")
        #expect(ScreenProportion.factor(forWidth: 320) == 0.96)
        #expect(ScreenProportion.factor(forWidth: 500) == 1.08)
    }

    @Test func thePagesTextGrowsWithTheTextSizeButStopsAtTheSecondAccessibilitySize() {
        let size = ScriptTextSize.medium
        #expect(size.points(for: .xxxLarge) > size.points(for: .large))
        #expect(size.points(for: .accessibility5) == size.points(for: .accessibility2))
    }
}
