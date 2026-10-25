//
//  QuickEditBrandKitTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Cue_Studio

/// Brand kits in the editor: one made from a video takes its styles, colors and logo; putting one on changes only the parts
/// chosen, keeping words, timing and places, in one undo step; its logo goes once, top right over the whole video (a second
/// time replaces the picture where it is); changing or deleting the kit, or the library's logo, never changes a video or
/// breaks the kit; and what each part would do is said first.
@MainActor
@Suite("Brand kits in the editor")
struct QuickEditBrandKitTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
        let library: MediaLibraryStore
        let kits: BrandKitStore
    }

    private func makeScenario() async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let toast = ToastService()
        let root = URL.temporaryDirectory.appending(path: "Brand-\(UUID().uuidString)", directoryHint: .isDirectory)
        let media = MediaLibraryStore(
            repository: LocalMediaLibraryRepository(directory: root.appending(path: "Library")), directory: root.appending(path: "Library")
        )
        let kits = BrandKitStore(repository: LocalBrandKitRepository(directory: root.appending(path: "Kits")), directory: root.appending(path: "Kits"))
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(),
            recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), mediaLibrary: media, brandKits: kits
        )
        await viewModel.prepare()
        viewModel.changeEdit { edit in
            edit.captions = [CaptionCue(text: "Comidas de SP", start: 0.3, end: 2.3), CaptionCue(text: "que são só pra turista.", start: 2.3, end: 4)]
            edit.showsCaptions = true
            var title = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 1, end: 4))
            title.text = "Three habits"
            title.center = OverlayPoint(x: 0.5, y: 0.2)
            edit.texts = [title]
        }
        return Scenario(viewModel: viewModel, toast: toast, library: media, kits: kits)
    }

    /// A see-through PNG logo.
    private func logoFile() throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.96, alpha: 1))
        context.fill(CGRect(x: 10, y: 5, width: 20, height: 10))
        let url = URL.temporaryDirectory.appending(path: "logo-\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    private var brandBlue: OverlayColor { .custom(red: 0.118, green: 0.4, blue: 0.961) }

    private func kit(_ scenario: Scenario) async throws -> BrandKit {
        let asset = try await scenario.library.add(fileAt: try logoFile(), name: "Acme logo").asset
        var kit = BrandKit(name: "Acme")
        kit.colors = [brandBlue, .yellow]
        kit.titleFont = .anton
        kit.captionFont = .montserrat
        var look = TextLook()
        look.color = brandBlue
        look.isUppercase = true
        kit.textStyle = BrandKitStyle(name: "Acme title", look: look)
        kit.logo = scenario.viewModel.brand.logo(from: asset)
        scenario.kits.save(kit)
        return try #require(scenario.kits.kits.first)
    }

    @Test func puttingAKitOnChangesOnlyTheChosenPartsInOneUndoStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let kit = try await kit(scenario)
        let before = viewModel.edit
        viewModel.brand.apply(kit, parts: [.textStyle, .fonts, .colors, .logo])
        let title = try #require(viewModel.edit.texts.first)
        // The look changed…
        #expect(title.color == brandBlue)
        #expect(title.isUppercase)
        #expect(title.font == .anton)
        #expect(viewModel.edit.captionCollection?.face == .montserrat)
        // …the words, timing and place didn't.
        #expect(title.text == "Three habits")
        #expect(title.span == before.texts[0].span)
        #expect(title.center == before.texts[0].center)
        #expect(viewModel.edit.captions.map(\.text) == before.captions.map(\.text))
        #expect(viewModel.edit.timeline == before.timeline)
        // The logo: once, a window over the whole video, in the top right.
        let logos = viewModel.edit.media.filter { $0.isLogo == true }
        #expect(logos.count == 1)
        #expect(logos.first?.layout == .window)
        #expect((logos.first?.center.x ?? 0) > 0.6)
        #expect((logos.first?.center.y ?? 1) < 0.3)
        #expect(viewModel.edit.brandKit == AppliedBrandKit(id: kit.id, name: "Acme", colors: [brandBlue, .yellow]))
        #expect(scenario.toast.message?.hasPrefix("Acme on this video") == true)
        // One Undo puts it all back.
        viewModel.undo()
        #expect(viewModel.edit.texts == before.texts)
        #expect(viewModel.edit.media == before.media)
        #expect(viewModel.edit.captionCollection == before.captionCollection)
        #expect(viewModel.edit.brandKit == nil)
        viewModel.redo()
        #expect(viewModel.edit.brandKit?.id == kit.id)
    }

    @Test func aSecondLogoReplacesThePictureWhereItIs() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let kit = try await kit(scenario)
        viewModel.brand.apply(kit, parts: [.logo])
        let id = try #require(viewModel.edit.media.first { $0.isLogo == true }?.id)
        viewModel.overlays.updateMedia(id) { $0.center = OverlayPoint(x: 0.2, y: 0.8) }
        viewModel.brand.apply(kit, parts: [.logo])
        let logos = viewModel.edit.media.filter { $0.isLogo == true }
        #expect(logos.count == 1)
        #expect(logos.first?.center == OverlayPoint(x: 0.2, y: 0.8))
    }

    @Test func changingOrDeletingTheKitOrTheLibrarysLogoChangesNoVideo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        var kit = try await kit(scenario)
        viewModel.brand.apply(kit, parts: [.textStyle, .colors, .logo])
        let worn = viewModel.edit
        kit.textStyle?.look.color = .red
        kit.colors = [.red]
        scenario.kits.save(kit)
        #expect(viewModel.edit == worn)
        // The library's logo goes: the kit keeps its own link to it.
        for asset in scenario.library.assets {
            scenario.library.remove(asset.id)
            try? FileManager.default.removeItem(at: scenario.library.url(of: asset))
        }
        #expect(scenario.kits.hasLogoFile(kit))
        viewModel.brand.deleteKit(kit.id)
        #expect(scenario.kits.kits.isEmpty)
        #expect(viewModel.edit == worn)
        // Undo of the delete brings the kit back whole.
        scenario.toast.action?.perform()
        #expect(scenario.kits.kit(kit.id)?.colors == [.red])
    }

    @Test func aKitFromThisVideoTakesItsStylesColorsAndLogo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let original = try await kit(scenario)
        viewModel.brand.apply(original, parts: [.textStyle, .logo])
        let made = viewModel.brand.kitFromThisVideo()
        #expect(made.textStyle?.look.color == brandBlue)
        #expect(made.captionStyle != nil)
        #expect(made.colors.first == brandBlue)
        #expect(made.logo != nil)
        #expect(made.name == "Brand kit")
        #expect(scenario.kits.kit(made.id) == nil)
    }

    @Test func whatEachPartDoesIsSaidFirst() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        var kit = try await kit(scenario)
        kit.coverStyle = BrandKitStyle(name: "Acme cover", look: CoverComposition(template: .educational).style)
        let changes = viewModel.brand.changes(for: kit)
        #expect(changes.map(\.part) == [.textStyle, .coverStyle, .fonts, .colors, .logo])
        #expect(changes.first { $0.part == .textStyle }?.title == "Text style · Acme title")
        #expect(changes.first { $0.part == .textStyle }?.detail.hasPrefix("On 1 text") == true)
        // No cover yet: said, not chosen.
        #expect(changes.first { $0.part == .coverStyle }?.isAvailable == false)
        #expect(changes.first { $0.part == .logo }?.detail == "Top right, over the whole video")
    }
}
