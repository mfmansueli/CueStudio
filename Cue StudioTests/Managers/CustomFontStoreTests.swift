//
//  CustomFontStoreTests.swift
//  Cue StudioTests
//

import CoreText
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Imported fonts: a whole TrueType file comes in under its family's name, is registered for Cue and drawn by the renderers
/// (preview and export share `TextFont`), letters it lacks in the system font; the same file twice, a font the iPhone already
/// has and a file that isn't a font are refused and leave nothing; removing keeps it for the videos that use it, and its
/// files go only once nothing names it; reopening finds it again; a video naming a family that isn't here draws in SF Pro.
/// Serialized: the renderers read one registry for the whole app.
@MainActor
@Suite("Imported fonts", .serialized)
struct CustomFontStoreTests {
    private func makeStore() -> (CustomFontStore, URL) {
        let folder = URL.temporaryDirectory.appending(path: "Fonts-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (CustomFontStore(repository: LocalCustomFontRepository(directory: folder), directory: folder), folder)
    }

    @Test func aFontComesInUnderItsFamilyAndIsDrawnByTheRenderers() async throws {
        let (store, folder) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        let file = try TestFonts.renamedAnton(to: family)
        let outcome = await store.importFonts(from: [file])
        #expect(outcome.added == [family])
        #expect(store.offered.map(\.name) == [family])
        let kept = try #require(store.families.first?.faces.first)
        #expect(kept.postScriptName == "\(family)-Regular")
        #expect((300...500).contains(kept.weight))
        // The copy is Cue's own: the picked file can go.
        try FileManager.default.removeItem(at: file)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: kept.fileName).path(percentEncoded: false)))
        // The renderers draw it, and offer it first.
        let font = TextFont.font(.custom(family), weight: .regular, size: 40, text: "Hello")
        #expect(font.fontName == "\(family)-Regular")
        #expect(TextOverlayFont.pickerFonts().first == .custom(family))
        #expect(TextOverlayFont.custom(family).label == family)
        #expect(!TextOverlayFont.custom(family).isMissing)
    }

    @Test func theRenderersDrawTheWordsInTheImportedFont() async throws {
        let (store, _) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        _ = await store.importFonts(from: [try TestFonts.renamedAnton(to: family)])
        func drawn(_ font: TextOverlayFont) throws -> Data {
            var text = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 0, end: 1))
            text.text = "BRAND"
            text.font = font
            text.weight = .regular
            text.hasShadow = false
            let image = try #require(TextOverlayRenderer.image(for: text, frameWidth: 1080))
            return try #require(image.pngData())
        }
        // The imported family is Anton under another name: the texts the export draws come out letter for letter as Anton,
        // and not as SF Pro (what a family that isn't here falls back to).
        #expect(try drawn(.custom(family)) == drawn(.anton))
        #expect(try drawn(.custom(family)) != drawn(.sfPro))
    }

    @Test func lettersTheFontLacksAreDrawnInTheSystemFont() async throws {
        let (store, _) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        _ = await store.importFonts(from: [try TestFonts.renamedAnton(to: family)])
        let font = TextFont.font(.custom(family), weight: .regular, size: 40, text: "日本")
        let cascade = font.fontDescriptor.fontAttributes[UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String)] as? [UIFontDescriptor]
        #expect(font.fontName == "\(family)-Regular")
        #expect(cascade?.isEmpty == false)
        // Drawn, the line has a width for every letter: none is a missing-glyph box of zero width.
        let width = ("Hi 日本" as NSString).size(withAttributes: [.font: font]).width
        #expect(width > ("Hi " as NSString).size(withAttributes: [.font: font]).width + 40)
    }

    @Test func theSameFileAFontTheIPhoneHasAndAFileThatIsntAFontLeaveNothing() async throws {
        let (store, folder) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        let file = try TestFonts.renamedAnton(to: family)
        _ = await store.importFonts(from: [file])
        let again = await store.importFonts(from: [file])
        #expect(again.added.isEmpty)
        #expect(again.alreadyHere == [family])
        // Cue's own Anton is already registered under the same PostScript name.
        let anton = try #require(Bundle.main.url(forResource: "Anton-Regular", withExtension: "ttf"))
        let bundled = await store.importFonts(from: [anton])
        #expect(bundled.problems.values.first == .alreadyInstalled("Anton"))
        let junk = URL.temporaryDirectory.appending(path: "junk-\(UUID().uuidString).ttf")
        try Data("not a font".utf8).write(to: junk)
        let notAFont = await store.importFonts(from: [junk])
        #expect(notAFont.problems.values.first == .notAFont)
        // Only the one font's file and the list are in the folder.
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(files.filter { $0 != "fonts.json" }.count == 1)
        #expect(store.families.count == 1)
    }

    @Test func removingKeepsItForVideosAndItsFilesGoOnceNothingNamesIt() async throws {
        let (store, folder) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        _ = await store.importFonts(from: [try TestFonts.renamedAnton(to: family)])
        let fileName = try #require(store.families.first?.faces.first?.fileName)
        let removed = try #require(store.remove(family))
        #expect(store.offered.isEmpty)
        // Still drawn: a video that uses it keeps it.
        #expect(TextFont.font(.custom(family), weight: .regular, size: 30, text: "Hi").fontName == "\(family)-Regular")
        store.restore(removed)
        #expect(store.offered.map(\.name) == [family])
        store.remove(family)
        // A saved video names it: it stays.
        let saved = "{\"font\":\"\(LibraryFileSweep.token(for: family))\"}"
        #expect(LibraryFileSweep.unusedFonts([family], saved: saved).isEmpty)
        // Nothing names it: its file goes and the family is forgotten.
        #expect(LibraryFileSweep.unusedFonts([family], saved: "{}") == [family])
        store.forget([family])
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: fileName).path(percentEncoded: false)))
        #expect(store.families.isEmpty)
        #expect(TextOverlayFont.custom(family).isMissing)
    }

    @Test func reopeningFindsTheFontsAgain() async throws {
        let (store, folder) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        _ = await store.importFonts(from: [try TestFonts.renamedAnton(to: family)])
        let reopened = CustomFontStore(repository: LocalCustomFontRepository(directory: folder), directory: folder)
        reopened.load()
        #expect(reopened.offered.map(\.name) == [family])
        #expect(TextFont.font(.custom(family), weight: .bold, size: 30, text: "Hi").fontName == "\(family)-Regular")
    }

    @Test func aVideoNamingAFamilyThatIsntHereDrawsInSFProAndKeepsTheName() throws {
        let missing = TextOverlayFont.custom("Brand Sans Gone")
        #expect(missing.isMissing)
        #expect(missing.label == "Brand Sans Gone")
        let system = UIFont.systemFont(ofSize: 30, weight: .bold)
        #expect(TextFont.font(missing, weight: .bold, size: 30, text: "Hi").fontName == system.fontName)
        #expect(TextOverlayFont.pickerFonts(including: missing).first == missing)
        #expect(BrandViewModel.missingFontNote(missing) != nil)
        // Saved and read back, the name stays; an earlier version (any value it doesn't know) reads SF Pro.
        let data = try JSONEncoder().encode([missing])
        #expect(try JSONDecoder().decode([TextOverlayFont].self, from: data) == [missing])
        #expect(try JSONDecoder().decode([TextOverlayFont].self, from: Data("[\"later-font\"]".utf8)) == [.sfPro])
    }
}
