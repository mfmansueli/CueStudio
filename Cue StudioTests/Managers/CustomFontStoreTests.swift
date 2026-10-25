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
/// files go only once nothing names it; reopening finds it again; a family left without its file is repaired by importing the
/// file again; a video naming a family that isn't here draws in SF Pro.
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

    @Test func importingARemovedFamilyAgainBringsItBackAndASweepLeavesIt() async throws {
        let (store, _) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        let file = try TestFonts.renamedAnton(to: family)
        _ = await store.importFonts(from: [file])
        store.remove(family)
        #expect(store.offered.isEmpty)
        let again = await store.importFonts(from: [file])
        #expect(again.added == [family])
        #expect(store.offered.map(\.name) == [family])
        // A sweep that found it unused before it came back leaves it.
        store.forget([family])
        #expect(store.families.map(\.name) == [family])
        #expect(!TextOverlayFont.custom(family).isMissing)
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

    /// Its family still in fonts.json, its file gone, Cue opened again (nothing registered): imported again, the file is back
    /// where the family says, drawn again, nothing doubled (the reviewer's case, 25/10).
    @Test func aFontWhoseFileWentIsRepairedByImportingItAgain() async throws {
        let (store, folder) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        let file = try TestFonts.renamedAnton(to: family)
        _ = await store.importFonts(from: [file])
        let fileName = try #require(store.families.first?.faces.first?.fileName)
        let reopened = try reopenWithoutItsFile(fileName, in: folder)
        #expect(reopened.families.map(\.name) == [family])
        #expect(TextOverlayFont.custom(family).isMissing)
        let again = await reopened.importFonts(from: [file])
        #expect(again.repaired == [family])
        #expect(again.alreadyHere.isEmpty)
        #expect(again.message == "\(family) is back · videos that use it show it again")
        #expect(reopened.drawable == [family])
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: fileName).path(percentEncoded: false)))
        #expect(!TextOverlayFont.custom(family).isMissing)
        #expect(TextFont.font(.custom(family), weight: .regular, size: 30, text: "Hi").fontName == "\(family)-Regular")
        #expect(reopened.families.map(\.faces.count) == [1])
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(files.filter { $0 != "fonts.json" } == [fileName])
        // The same file once more, now that it's here: already in the fonts.
        #expect(await reopened.importFonts(from: [file]).alreadyHere == [family])
    }

    /// A video whose title is in that font: imported again from the picker, the preview draws again and the note goes.
    @Test func aVideoInAFontWhoseFileWentDrawsInItAgainOnceItsImportedAgain() async throws {
        let (store, folder) = makeStore()
        defer { store.eraseAll() }
        let family = TestFonts.uniqueFamily()
        let file = try TestFonts.renamedAnton(to: family)
        _ = await store.importFonts(from: [file])
        let reopened = try reopenWithoutItsFile(try #require(store.families.first?.faces.first?.fileName), in: folder)
        let (viewModel, toast, player) = await editor(fonts: reopened)
        viewModel.changeEdit { edit in
            var title = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 1, end: 4))
            title.text = "Three habits"
            title.font = .custom(family)
            edit.texts = [title]
        }
        #expect(viewModel.brand.missingFontNote(.custom(family)) != nil)
        let redraws = player.redraws
        await viewModel.brand.importFonts([file])
        #expect(toast.message == "\(family) is back · videos that use it show it again")
        #expect(viewModel.brand.missingFontNote(.custom(family)) == nil)
        #expect(player.redraws > redraws)
        #expect(viewModel.edit.texts.map(\.font) == [.custom(family)])
    }

    /// Cue opened again after the file `fileName` went (its family left in fonts.json): nothing registered.
    private func reopenWithoutItsFile(_ fileName: String, in folder: URL) throws -> CustomFontStore {
        let url = folder.appending(path: fileName)
        CustomFontFiles.unregister(url)
        try FileManager.default.removeItem(at: url)
        let reopened = CustomFontStore(repository: LocalCustomFontRepository(directory: folder), directory: folder)
        reopened.load()
        return reopened
    }

    private func editor(fonts: CustomFontStore) async -> (QuickEditViewModel, ToastService, FakeEditPlayback) {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let toast = ToastService()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player, mediaImporter: FakeMediaImporter(),
            recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), fonts: fonts
        )
        await viewModel.prepare()
        return (viewModel, toast, player)
    }

    @Test func aVideoNamingAFamilyThatIsntHereDrawsInSFProAndKeepsTheName() throws {
        let missing = TextOverlayFont.custom("Brand Sans Gone")
        #expect(missing.isMissing)
        #expect(missing.label == "Brand Sans Gone")
        let system = UIFont.systemFont(ofSize: 30, weight: .bold)
        #expect(TextFont.font(missing, weight: .bold, size: 30, text: "Hi").fontName == system.fontName)
        #expect(TextOverlayFont.pickerFonts(including: missing).first == missing)
        // Saved and read back, the name stays; an earlier version (any value it doesn't know) reads SF Pro.
        let data = try JSONEncoder().encode([missing])
        #expect(try JSONDecoder().decode([TextOverlayFont].self, from: data) == [missing])
        #expect(try JSONDecoder().decode([TextOverlayFont].self, from: Data("[\"later-font\"]".utf8)) == [.sfPro])
    }
}
