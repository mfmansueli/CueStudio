//
//  CaptionStyleCopyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Apply this style to captions" as a rule: the text's look without its size or height, what it
/// replaces, the highlight it keeps (or moves when it would vanish), and that only the look changes.
@Suite("Caption style copy")
struct CaptionStyleCopyTests {
    private func title(color: OverlayColor = .white, background: TextOverlayBackground = .none) -> TextOverlay {
        var text = TextOverlay(role: .title, look: TypePreset.editorial.look(for: .title), preset: .editorial, span: TimeSpan(start: 0, end: 2))
        text.size = 64
        text.center = OverlayPoint(x: 0.5, y: 0.3)
        text.color = color
        text.background = background
        text.backgroundColor = .yellow
        text.backgroundOpacity = 1
        text.glow = 0.4
        text.text = "5 comidas de SP"
        return text
    }

    private func edit() -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.captions = [CaptionCue(text: "Comidas de SP", start: 0, end: 2)]
        edit.showsCaptions = true
        return edit
    }

    @Test func theLookIsTheTextsButNotItsSizeOrHeight() {
        let text = title()
        let look = CaptionStyleCopy.look(from: text)
        #expect(look.font == text.font && look.weight == text.weight)
        #expect(look.color == text.color && look.glow == text.glow)
        #expect(look.background == text.background && look.hasShadow == text.hasShadow)
        #expect(look.sizeScale == 1)
        #expect(look.verticalOffset == 0)
    }

    @Test func itSaysWhichPresetItReplaces() {
        var edit = edit()
        edit.captionCollection = CaptionSettings(theme: .pop)
        #expect(CaptionStyleCopy.replaced(in: edit) == .preset("Pop"))
        edit.captionCollection?.customLook = CaptionStyleCopy.look(from: title())
        #expect(CaptionStyleCopy.replaced(in: edit) == .custom)
        edit.captionCollection = nil
        edit.captionLook = TypePreset.soft.look(for: .caption)
        edit.captionPreset = .soft
        #expect(CaptionStyleCopy.replaced(in: edit) == .preset(TypePreset.soft.label))
        edit.captionLook = nil
        #expect(CaptionStyleCopy.replaced(in: edit) == .custom)
    }

    @Test func onTheCollectionOnlyTheLookChanges() {
        var edit = edit()
        var settings = CaptionSettings(theme: .educational)
        settings.center = OverlayPoint(x: 0.42, y: 0.31)
        settings.sizeScale = 1.3
        settings.accent = .lime
        edit.captionCollection = settings
        edit.captionAnimation = .groups
        edit.captionPosition = .top
        var snapshot = EditSnapshot(edit)
        let before = snapshot
        let look = CaptionStyleCopy.look(from: title())
        CaptionStyleCopy.apply(look, to: &snapshot)
        var expected = settings
        expected.customLook = look
        #expect(snapshot.captionCollection == expected)
        // Everything else is as it was: lines, texts, how lines appear, where they sit.
        var rest = snapshot
        rest.captionCollection = before.captionCollection
        #expect(rest == before)
    }

    @Test func aHighlightThatWouldVanishMovesToOneThatStandsOut() {
        var edit = edit()
        edit.captionCollection = CaptionSettings(theme: .cue)
        let yellow = CaptionStyleCopy.look(from: title(color: .yellow))
        #expect(CaptionStyleCopy.changedHighlight(in: edit, for: yellow) == .white)
        var snapshot = EditSnapshot(edit)
        CaptionStyleCopy.apply(yellow, to: &snapshot)
        #expect(snapshot.captionCollection?.accent == .white)
        // White on a white title: Cue's yellow already stands out, nothing moves.
        let white = CaptionStyleCopy.look(from: title())
        #expect(CaptionStyleCopy.changedHighlight(in: edit, for: white) == nil)
        // Black words on a yellow fill: yellow would vanish into the fill.
        let boxed = CaptionStyleCopy.look(from: title(color: .offBlack, background: .box))
        #expect(CaptionStyleCopy.changedHighlight(in: edit, for: boxed) == .white)
    }

    @Test func captionsFromBeforeTheCollectionKeepTheirSize() {
        var edit = edit()
        edit.captionCollection = nil
        var old = TypePreset.soft.look(for: .caption)
        old.sizeScale = 1.2
        edit.captionLook = old
        edit.captionPreset = .soft
        var snapshot = EditSnapshot(edit)
        let look = CaptionStyleCopy.look(from: title())
        CaptionStyleCopy.apply(look, to: &snapshot)
        var expected = look
        expected.sizeScale = 1.2
        #expect(snapshot.captionLook == expected)
        #expect(snapshot.captionPreset == nil)
        #expect(snapshot.captionCollection == nil)
        // Nothing to light differently: the type look has no highlight color of its own.
        #expect(CaptionStyleCopy.changedHighlight(in: edit, for: look) == nil)
    }

    @Test func aCopiedLookIsSavedAndReadBack() throws {
        var edit = edit()
        edit.captionCollection?.customLook = CaptionStyleCopy.look(from: title())
        let data = try JSONEncoder().encode(edit)
        let read = try JSONDecoder().decode(TakeEdit.self, from: data)
        #expect(read.captionCollection == edit.captionCollection)
        #expect(read.captionCollection?.customLook != nil)
    }

    @Test func settingsSavedBeforeItReadWithoutOne() throws {
        let settings = CaptionSettings(theme: .pop)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        #expect(json["customLook"] == nil)
        json["customLook"] = nil
        let read = try JSONDecoder().decode(CaptionSettings.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(read == settings)
        #expect(read.customLook == nil)
    }
}
