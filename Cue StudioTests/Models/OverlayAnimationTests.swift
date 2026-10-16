//
//  OverlayAnimationTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Ready-made motion: each preset comes in over its duration and lands where the item is; it sits over the keyframes instead
/// of replacing them; In and out also goes out; and texts and photos saved before it have none.
@Suite("Overlay animation")
struct OverlayAnimationTests {
    private let base = OverlayMotion.State(center: OverlayPoint(x: 0.5, y: 0.4), scale: 1, opacity: 1)

    private func motion(_ preset: MotionPreset, keyframes: [OverlayKeyframe] = [], length: TimeInterval = 4) -> OverlayMotion {
        OverlayMotion(keyframes, animation: OverlayAnimation(preset: preset, duration: 0.6, intensity: 0.5), length: length, base: base)
    }

    @Test func everyPresetLandsWhereTheItemIs() throws {
        for preset in MotionPreset.allCases where preset != .gentleZoom {
            let landed = try #require(motion(preset).state(at: 1.5))
            #expect(abs(landed.center.x - 0.5) < 0.000_1 && abs(landed.center.y - 0.4) < 0.000_1, "\(preset)")
            #expect(abs(landed.scale - 1) < 0.02, "\(preset)")
            #expect(abs(landed.opacity - 1) < 0.000_1, "\(preset)")
        }
    }

    @Test func entrancesStartHiddenAndMoved() throws {
        #expect(try #require(motion(.fade).state(at: 0)).opacity == 0)
        let slide = try #require(motion(.slideUp).state(at: 0))
        #expect(slide.center.y > 0.4)
        let slideIn = try #require(motion(.slideIn).state(at: 0))
        #expect(slideIn.center.x < 0.5)
        let pop = try #require(motion(.pop).state(at: 0))
        #expect(pop.scale < 1)
    }

    @Test func gentleZoomGrowsTheWholeTime() throws {
        let zoom = motion(.gentleZoom)
        let start = try #require(zoom.state(at: 0)).scale
        let middle = try #require(zoom.state(at: 2)).scale
        let end = try #require(zoom.state(at: 4)).scale
        #expect(start < middle && middle < end)
    }

    @Test func inAndOutGoesOutBeforeTheEnd() throws {
        let both = motion(.inAndOut)
        #expect(try #require(both.state(at: 2)).opacity == 1)
        #expect(try #require(both.state(at: 4)).opacity < 0.01)
    }

    @Test func itSitsOverTheKeyframes() throws {
        let keyframes = [
            OverlayKeyframe(time: 0, center: OverlayPoint(x: 0.2, y: 0.2)), OverlayKeyframe(time: 4, center: OverlayPoint(x: 0.8, y: 0.2)),
        ]
        let moved = try #require(motion(.fade, keyframes: keyframes).state(at: 2))
        #expect(abs(moved.center.x - 0.5) < 0.000_1)
        #expect(moved.opacity == 1)
        #expect(try #require(motion(.fade, keyframes: keyframes).state(at: 0)).opacity == 0)
    }

    @Test func aShortItemShortensItsEntrance() throws {
        let short = OverlayMotion([], animation: OverlayAnimation(preset: .fade, duration: 1.5), length: 1, base: base)
        // Half of the item at most.
        #expect(try #require(short.state(at: 0.5)).opacity == 1)
    }

    @Test func textsSavedBeforeHaveNoAnimation() throws {
        let text = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 0, end: 2))
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(text)) as? [String: Any])
        #expect(json["animation"] == nil)
        json["animation"] = nil
        let decoded = try JSONDecoder().decode(TextOverlay.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.animation == nil)
        var animated = text
        animated.animation = OverlayAnimation(preset: .pop)
        #expect(try JSONDecoder().decode(TextOverlay.self, from: JSONEncoder().encode(animated)).animation?.preset == .pop)
    }

    @Test func theExportDrawsTheTextsMotion() {
        var text = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 0, end: 3))
        text.text = "Hello"
        text.animation = OverlayAnimation(preset: .fade)
        let overlays = TextOverlayRenderer.overlays([(text, TimeSpan(start: 1, end: 4))], frame: CGSize(width: 360, height: 640))
        #expect(overlays.first?.motion?.state(at: 0)?.opacity == 0)
        #expect(overlays.first?.motion?.state(at: 2)?.opacity == 1)
    }
}
