//
//  SafeZoneOverlayTests.swift
//  Cue StudioTests
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Cue_Studio

/// The safe zone's caption, which must be readable wherever the zone's corner lands: not past the screen's left edge (the preview fills
/// the screen and the zone's left edge runs past it) and not under the controls.
@Suite("SafeZoneOverlay")
struct SafeZoneOverlayTests {
    /// A Pro Max with its controls from y = 690 down.
    private let readable = CGRect(x: 0, y: 0, width: 440, height: 690)

    @Test func aCornerInViewKeepsTheUsualPlace() {
        let content = CGRect(x: 30, y: 107, width: 450, height: 500)
        for visible in [nil, readable] {
            let insets = SafeZoneOverlay.labelInsets(content: content, visible: visible)
            #expect(insets.leading == 9 && insets.bottom == 7)
        }
    }

    @Test func aZoneCutByTheScreensLeftEdgeMovesTheCaptionIn() {
        // Reels with the preview filling a Pro Max: the zone starts 19 pt left of the screen.
        let content = CGRect(x: -19, y: 107, width: 450, height: 500)
        let insets = SafeZoneOverlay.labelInsets(content: content, visible: readable)
        #expect(content.minX + insets.leading >= readable.minX + 9, "The caption starts offscreen")
    }

    @Test func aZoneEndingUnderTheControlsLiftsTheCaptionAboveThem() {
        // Filling a Pro Max, TikTok's clear area ends at y = 752: under the controls, which start at 690.
        let content = CGRect(x: -19, y: 107, width: 450, height: 645)
        let insets = SafeZoneOverlay.labelInsets(content: content, visible: readable)
        #expect(content.maxY - insets.bottom <= readable.maxY, "The caption is under the controls")
    }

    @Test func aShortZoneNeverPushesTheCaptionPastItsOwnTop() {
        let content = CGRect(x: 30, y: 600, width: 400, height: 80)
        let insets = SafeZoneOverlay.labelInsets(content: content, visible: CGRect(x: 0, y: 0, width: 440, height: 300))
        #expect(insets.bottom <= content.height - 24 + 0.001)
    }
}
