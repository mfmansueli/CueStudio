//
//  TextEffectModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Text effects, a text's turn, its block and how its letters are drawn as they are saved: old projects read without them
/// and save without them (their letters drawn the first way), new ones read back the same, values a newer version (or a
/// broken file) wrote fall back to the kind's own, and a keyframe's turn moves the text from one keyframe to the next.
@Suite("Text effects · model")
struct TextEffectModelTests {
    private let span = TimeSpan(start: 1, end: 4)

    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(value))
    }

    private func json(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    // MARK: - Saving

    @Test func aTextWithoutAnEffectSavesAsBefore() throws {
        let text = TextOverlay(role: .title, look: TypePreset.orbit.look(for: .title), preset: .orbit, span: span)
        let keys = try json(text).keys
        #expect(!keys.contains("effect") && !keys.contains("rotation") && !keys.contains("block"))
        let read = try roundTrip(text)
        #expect(read.effect == nil && read.rotation == 0 && read.block == nil)
    }

    @Test func anEffectATurnAndABlockReadBackTheSame() throws {
        var text = TextOverlay(role: .title, look: TypePreset.gold.look(for: .title), preset: .gold, span: span)
        text.text = "Olá, ação"
        text.rotation = -0.4
        text.block = TextBlock(width: 180, size: 52)
        text.effect?.tone = .rose
        text.effect?.motion = .still
        let read = try roundTrip(text)
        #expect(read == text)
        #expect(read.effect?.kind == .gold && read.effect?.tone == .rose && read.effect?.motion == .still)
    }

    @Test func aTextSavedBeforeKeepsItsLettersTheFirstWay() throws {
        var text = TextOverlay(role: .title, look: TypePreset.impact.look(for: .title), preset: .impact, span: span)
        #expect(text.lettering == .outside)
        #expect(try json(text)["lettering"] as? String == "outside")
        #expect(try roundTrip(text).lettering == .outside)
        text.lettering = .centered
        #expect(try json(text)["lettering"] == nil)
        #expect(try roundTrip(text).lettering == .centered)
        // A look saved without it reads the first way too; one a newer version wrote reads as today's.
        let look = try JSONDecoder().decode(TextLook.self, from: Data(#"{"hasOutline":true}"#.utf8))
        #expect(look.lettering == .centered)
        #expect(try JSONDecoder().decode(TextLook.self, from: Data(#"{"lettering":"hologram"}"#.utf8)).lettering == .outside)
        // A style picked today draws today's.
        TypePreset.impact.look(for: .title).apply(to: &text)
        #expect(text.lettering == .outside)
    }

    @Test func aTurnIsKeptWithinOneTurn() throws {
        var text = TextOverlay(role: .title, look: TypePreset.orbit.look(for: .title), preset: .orbit, span: span)
        text.rotation = 7 * .pi
        let read = try roundTrip(text)
        #expect(abs(abs(read.rotation) - .pi) < 0.000_1)
    }

    @Test func anEffectANewerVersionWroteFallsBackToTheKindsOwn() throws {
        let data = Data("""
        {"kind":"hologram","accent":"ultraviolet","tone":"bronze","intensity":7,"motion":"spin","duration":99,"direction":"diagonal"}
        """.utf8)
        let effect = try JSONDecoder().decode(TextEffect.self, from: data)
        #expect(effect.kind == TextEffectKind.fallback)
        #expect(effect.accent == TextEffectKind.fallback.defaultAccent)
        #expect(effect.tone == .gold)
        #expect(effect.intensity == 1)
        #expect(effect.motion == .animated)
        #expect(effect.duration == TextEffectKind.durationRange.upperBound)
        #expect(TextEffectKind.fallback.directions.contains(effect.direction))
    }

    @Test func aDirectionTheKindDoesntOfferIsLeftOut() {
        let effect = TextEffect(kind: .pop3D, direction: .middle)
        #expect(effect.direction == TextEffectKind.pop3D.directions[0])
        #expect(TextEffect(kind: .wave, direction: .middle).direction == .middle)
    }

    @Test func aKeyframeWithoutATurnReadsAsBefore() throws {
        let data = Data(#"{"id":"7B1C4A0B-6C5D-4E7A-9C11-3E2F5A6B7C8D","time":1,"center":{"x":0.5,"y":0.5},"scale":1,"opacity":1,"easing":"smooth"}"#.utf8)
        let keyframe = try JSONDecoder().decode(OverlayKeyframe.self, from: data)
        #expect(keyframe.rotation == nil)
    }

    @Test func aBlockIsNeverNarrowerThanItsMinimum() {
        #expect(TextBlock(width: 3, size: 40).width == TextBlock.minimumWidth)
        #expect(abs(TextBlock(width: 200, size: 40).scale(at: 80) - 2) < 0.000_1)
    }

    // MARK: - Where it goes

    @Test func captionsNeverWearAnEffect() {
        let caption = TextOverlay.caption("Olá", look: TypePreset.neon.look(for: .caption), position: .bottom, span: span)
        #expect(caption.effect == nil)
    }

    @Test func aMotionOfItsOwnPlaysInsteadOfTheEffects() {
        var text = TextOverlay(role: .title, look: TypePreset.wave.look(for: .title), preset: .wave, span: span)
        #expect(text.playsEffectMotion)
        text.animation = OverlayAnimation(preset: .fade, duration: 0.5, intensity: 0.5)
        #expect(!text.playsEffectMotion)
        text.animation = nil
        text.effect?.motion = .still
        #expect(!text.playsEffectMotion)
    }

    @Test func aClassicStyleTakesTheEffectOffAndAnEffectStylePutsItOn() {
        var text = TextOverlay(role: .title, look: TypePreset.gold.look(for: .title), preset: .gold, span: span)
        #expect(text.effect?.kind == .gold)
        TypePreset.orbit.look(for: .title).apply(to: &text)
        #expect(text.effect == nil)
        TypePreset.headline.look(for: .title).apply(to: &text)
        #expect(text.effect?.kind == .headline)
        TypePreset.orbit.look(for: .title).apply(to: &text, keeping: [.effect])
        #expect(text.effect?.kind == .headline)
    }

    @Test func everyEffectStyleHasItsEffectAndTheSixAreAllThere() {
        #expect(TypePreset.effectPresets.compactMap(\.effect) == TextEffectKind.allCases)
        #expect(TypePreset.editorPresets.allSatisfy { $0.effect == nil })
        for preset in TypePreset.effectPresets {
            #expect(preset.look(for: .title).effect?.kind == preset.effect, "\(preset)")
        }
    }

    // MARK: - Turning with keyframes

    @Test func keyframesTurnTheTextFromOneToTheNext() throws {
        let keyframes = [
            OverlayKeyframe(time: 0, center: .center, rotation: 0),
            OverlayKeyframe(time: 1, center: .center, easing: .linear, rotation: .pi / 2),
        ]
        let motion = OverlayMotion(keyframes, animation: nil, length: 2, base: .init(center: .center, scale: 1, opacity: 1, rotation: 0.3))
        let middle = try #require(motion.state(at: 0.5))
        #expect(abs(middle.rotation - .pi / 4) < 0.000_1)
        #expect(abs((motion.state(at: 2)?.rotation ?? 0) - .pi / 2) < 0.000_1)
    }

    @Test func aKeyframeWithoutATurnKeepsTheTextsOwn() throws {
        let keyframes = [OverlayKeyframe(time: 0, center: .center), OverlayKeyframe(time: 1, center: OverlayPoint(x: 0.2, y: 0.2))]
        let motion = OverlayMotion(keyframes, animation: nil, length: 2, base: .init(center: .center, scale: 1, opacity: 1, rotation: 0.3))
        #expect(abs((motion.state(at: 0.5)?.rotation ?? 0) - 0.3) < 0.000_1)
    }
}
