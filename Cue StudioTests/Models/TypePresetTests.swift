//
//  TypePresetTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Type presets and looks: set differently for titles and captions, applied without touching
/// what a text says or when, and read back from old projects without them.
@Suite("Type presets")
struct TypePresetTests {
    private let span = TimeSpan(start: 1, end: 3)

    @Test func theEditorOffersTheEightPresetsOfTheDesign() {
        #expect(TypePreset.editorPresets == [.cue, .editorial, .bold, .pop, .soft, .minimal, .label, .paper])
        let cue = TypePreset.cue.look(for: .title)
        #expect(cue.font == .dmSans && cue.weight == .heavy && cue.color == .black)
        #expect(cue.background == .box && cue.backgroundColor == .yellow)
        let label = TypePreset.label.look(for: .title)
        #expect(label.isUppercase && abs(label.tracking - 0.08) < 0.000_001 && abs(label.sizeScale - 0.62) < 0.000_001)
        #expect(TypePreset.editorial.look(for: .title).font == .dmSerif)
        #expect(TypePreset.bold.look(for: .title).hasOutline)
    }

    @Test func aHeavyTitleIsOneStepLighterOnCaptions() {
        // A line read word by word: Cue's heavy title face is too dense.
        #expect(TypePreset.cue.look(for: .title).weight == .heavy)
        #expect(TypePreset.cue.look(for: .caption).weight == .bold)
        #expect(TypePreset.editorial.look(for: .caption).sizeScale <= 1.1)
    }

    @Test func captionsStayReadable() {
        for preset in TypePreset.allCases {
            let look = preset.look(for: .caption)
            // A line of five words fits, and something separates it from the picture.
            #expect(look.sizeScale <= 1.2, "\(preset)")
            #expect(look.hasShadow || look.hasOutline || (look.background != .none && look.backgroundOpacity >= 0.4), "\(preset)")
        }
    }

    @Test func aLookSetsTheTypeButNotTheWordsOrTheTime() {
        var text = TextOverlay(role: .hook, look: TypePreset.cue.look(for: .title), preset: .cue, span: span)
        text.text = "Wait for it"
        TypePreset.label.look(for: .title).apply(to: &text)
        #expect(text.text == "Wait for it")
        #expect(text.span == span)
        #expect(text.role == .hook)
        #expect(text.background == .box)
        #expect(text.isUppercase)
        #expect(text.size == TextOverlayRole.hook.baseSize * TypePreset.label.look(for: .title).sizeScale)
    }

    @Test func keptFieldsStayAsTheyWere() {
        var text = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: span)
        text.color = .pink
        text.center = OverlayPoint(x: 0.3, y: 0.7)
        TypePreset.pop.look(for: .title).apply(to: &text, keeping: [.color, .position])
        #expect(text.color == .pink)
        #expect(text.center == OverlayPoint(x: 0.3, y: 0.7))
        #expect(text.hasOutline)
        #expect(text.font == .spaceGrotesk)
    }

    @Test func aTextsLookReadsBackTheSame() {
        for preset in TypePreset.allCases {
            let look = preset.look(for: .title)
            let text = TextOverlay(role: .title, look: look, preset: preset, span: span)
            let read = TextLook(of: text)
            #expect(abs(read.sizeScale - look.sizeScale) < 0.000_001, "\(preset)")
            #expect(abs(read.verticalOffset - look.verticalOffset) < 0.000_001, "\(preset)")
            var same = read
            same.sizeScale = look.sizeScale
            same.verticalOffset = look.verticalOffset
            #expect(same == look, "\(preset)")
        }
    }

    @Test func captionsUseTheirOwnBaseSizeAndPosition() {
        let look = TypePreset.impact.look(for: .caption)
        let line = TextOverlay.caption("and that's the trick", look: look, position: .top, span: span)
        #expect(line.size == TextLook.captionBaseSize * look.sizeScale)
        #expect(line.center.y == CaptionPosition.top.verticalFraction)
        #expect(line.isUppercase)
    }

    @Test func letterSpacingWidensTheDrawing() {
        var text = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: span)
        text.text = "Spacing"
        text.tracking = 0
        let tight = TextOverlayRenderer.size(for: text, frameWidth: 402)
        text.tracking = 0.2
        let wide = TextOverlayRenderer.size(for: text, frameWidth: 402)
        #expect(wide.width > tight.width)
    }

    // MARK: - Old projects

    @Test func aTextSavedBeforePresetsReadsWithNoneOfThem() throws {
        let json = """
        {"id": "\(UUID().uuidString)", "text": "Hello", "role": "title", "font": "classic", "weight": "bold", "size": 30,
         "isUppercase": false, "alignment": "center", "color": "white", "background": "box", "backgroundColor": "black",
         "hasShadow": true, "hasOutline": false, "center": {"x": 0.5, "y": 0.2}, "span": {"start": 1, "end": 2}}
        """
        let text = try JSONDecoder().decode(TextOverlay.self, from: Data(json.utf8))
        #expect(text.tracking == 0)
        #expect(text.backgroundOpacity == 1)
        #expect(text.preset == nil)
        #expect(text.customized.isEmpty)
        #expect(text.background == .box)
    }

    @Test func aTextKeepsItsPresetAndChangesThroughSaving() throws {
        var text = TextOverlay(role: .callout, look: TypePreset.soft.look(for: .title), preset: .soft, span: span)
        text.customized = [.color, .size]
        text.tracking = 0.05
        let decoded = try JSONDecoder().decode(TextOverlay.self, from: JSONEncoder().encode(text))
        #expect(decoded == text)
    }

    @Test func aLookOutOfRangeIsClamped() throws {
        let json = #"{"font": "serif", "sizeScale": 9, "tracking": -3, "backgroundOpacity": 4, "weight": "unknown"}"#
        let look = try JSONDecoder().decode(TextLook.self, from: Data(json.utf8))
        #expect(look.font == .serif)
        #expect(look.sizeScale == TextLook.sizeScaleRange.upperBound)
        #expect(look.tracking == TextLook.trackingRange.lowerBound)
        #expect(look.backgroundOpacity == 1)
        #expect(look.weight == .bold)
    }

    @Test func anEditSavedBeforePresetsKeepsItsCaptionStyleAndNewTextsFollowItsOldStyle() throws {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.creatorStyle = .social
        edit.captionStyle = .highlight
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        for key in ["captionLook", "captionPreset", "textLook", "textPreset"] { object[key] = nil }
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.captionLook == nil)
        #expect(decoded.captionStyle == .highlight)
        // New texts in an old project still start from its style.
        let text = decoded.newText(.callout, span: span)
        #expect(text.background == .pill)
        #expect(text.preset == nil)
    }

    @Test func undoKeepsTheTypeOfTextsAndCaptions() throws {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.textLook = TypePreset.minimal.look(for: .title)
        edit.textPreset = .minimal
        edit.captionLook = TypePreset.pop.look(for: .caption)
        edit.captionPreset = .pop
        let step = EditSnapshot(edit)
        let decoded = try JSONDecoder().decode(EditSnapshot.self, from: JSONEncoder().encode(step))
        #expect(decoded == step)
        #expect(decoded.captionPreset == .pop)
    }
}
