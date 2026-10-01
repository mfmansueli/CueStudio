//
//  TextStyleEditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One Font or Color change, the same on a text and on the captions' look.
@Suite("Text style edit")
struct TextStyleEditTests {
    private let text = TextOverlay(
        role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0, end: 3)
    )

    @Test func aFamilyWithOneWeightTakesIt() {
        var changed = text
        TextStyleEdit.font(.dmSerif).apply(to: &changed)
        #expect(changed.font == .dmSerif)
        #expect(changed.weight == .regular)
        TextStyleEdit.weight(.heavy).apply(to: &changed)
        #expect(changed.weight == .regular)
    }

    @Test func sizeIsInTheDesignsPointsAndOnlyForTexts() {
        var changed = text
        TextStyleEdit.size(30).apply(to: &changed)
        #expect(abs(changed.size - 30 * TextOverlayRole.designScale) < 0.000_1)
        TextStyleEdit.size(90).apply(to: &changed)
        #expect(abs(changed.size - 56 * TextOverlayRole.designScale) < 0.000_1)
        var look = TypePreset.cue.look(for: .caption)
        let before = look
        TextStyleEdit.size(30).apply(to: &look)
        #expect(look == before)
    }

    @Test func shadowStylesMapToShadowAndOutline() {
        var changed = text
        TextStyleEdit.shadow(.outline).apply(to: &changed)
        #expect(changed.hasOutline && changed.hasShadow)
        #expect(TextShadowStyle(hasShadow: changed.hasShadow, hasOutline: changed.hasOutline) == .outline)
        TextStyleEdit.shadow(.none).apply(to: &changed)
        #expect(!changed.hasOutline && !changed.hasShadow)
        TextStyleEdit.shadow(.soft).apply(to: &changed)
        #expect(TextShadowStyle(hasShadow: changed.hasShadow, hasOutline: changed.hasOutline) == .soft)
    }

    @Test func eachChangeIsRememberedAsItsField() {
        #expect(TextStyleEdit.font(.dmSans).field == .font)
        #expect(TextStyleEdit.backgroundColor(.yellow).field == .background)
        #expect(TextStyleEdit.shadow(.soft).field == .shadow)
    }
}
