//
//  TextWindowResizeTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// Dragging the corner of the Selfie text window.
@Suite("TextWindowResize")
struct TextWindowResizeTests {
    /// 28 pt text at 1.35 line spacing, on a 402 pt wide screen.
    private let line: CGFloat = 37.8
    private let screen: CGFloat = 402

    private func resize(width: Double = 0.93, height: Double = 300, by translation: CGSize) -> TextWindowResize {
        TextWindowResize(startWidth: width, startHeight: height, translation: translation, screenWidth: screen, lineHeight: line)
    }

    @Test func notMovingKeepsTheSize() {
        let result = resize(width: 0.8, height: 280, by: .zero)
        #expect(result.width == 0.8)
        #expect(result.height == 280)
    }

    @Test func draggingLeftNarrowsTheWindowFromBothSides() {
        // 60 pt to the left takes 120 pt off the width: 0.8 → 0.8 − 120/402.
        let result = resize(width: 0.8, by: CGSize(width: -60, height: 0))
        #expect(abs(result.width - (0.8 - 120.0 / 402.0)) < 0.001)
    }

    @Test func widthStaysBetweenTheLimits() {
        #expect(resize(by: CGSize(width: 500, height: 0)).width == PrompterSettings.readingWidthRange.upperBound)
        #expect(resize(by: CGSize(width: -500, height: 0)).width == PrompterSettings.readingWidthRange.lowerBound)
    }

    @Test func widthSettlesOnTheUsualSizes() {
        // 0.62 is within 2.5% of 0.6.
        let result = resize(width: 0.5, by: CGSize(width: 0.12 * 402 / 2, height: 0))
        #expect(result.width == 0.6)
        #expect(resize(width: 0.93, by: CGSize(width: -1, height: 0)).width == PrompterSettings.defaultReadingWidth)
    }

    @Test func heightFollowsTheFingerScaledForTheReadingLine() {
        // The window's top moves with its height, so 30 pt of finger is 30 / 0.75 = 40 pt of height.
        let result = resize(height: 200.5, by: CGSize(width: 0, height: 30))
        #expect(abs(result.height - 240.5) < 0.001)
    }

    @Test func heightStaysBetweenTheLimits() {
        // The tallest window settles on whole lines, so it can stop a few points short of the limit.
        let tallest = resize(by: CGSize(width: 0, height: 900)).height
        #expect(tallest <= PrompterSettings.textWindowHeightRange.upperBound)
        #expect(tallest > PrompterSettings.textWindowHeightRange.upperBound - Double(TextWindowResize.heightSnapReach))
        #expect(resize(by: CGSize(width: 0, height: -900)).height == PrompterSettings.textWindowHeightRange.lowerBound)
    }

    @Test func heightSettlesOnWholeLines() {
        // 6 lines is 226.8 pt; 5 pt away it settles on it.
        let result = resize(height: 221.8, by: .zero)
        #expect(abs(result.height - 6 * Double(line)) < 0.001)
        #expect(result.lines == 6)
    }

    @Test func aWindowIsNeverShorterThanThreeLines() {
        // Large text: three lines are taller than the smallest window.
        let big = TextWindowResize(startWidth: 0.93, startHeight: 300, translation: CGSize(width: 0, height: -900), screenWidth: screen, lineHeight: 70)
        #expect(big.height >= 3 * 70)
        #expect(big.lines >= 3)
    }

    @Test func theLabelSaysWidthAndLines() {
        let result = resize(width: 0.75, height: 6 * Double(line), by: .zero)
        #expect(result.label.contains("75"))
        #expect(result.label.contains("6"))
    }
}
