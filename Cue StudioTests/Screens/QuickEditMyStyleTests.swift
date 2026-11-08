//
//  QuickEditMyStyleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Meu estilo" (owner, 08/11/2026: F, G, H, Template): the kit keeps the creator's Editing and can be the one new videos open
/// in. A new video opens in it with "Your style is on · Undo" (Undo takes it off that video only, and it isn't put on again);
/// a video that was already edited keeps what it has. Editing readies the tools and cuts nothing; Studio Voice is its own part.
/// What the creator styled by hand on titles and caption lines stays unless they ask, said with counts. A template is tried on
/// before it stays, keeps a kit's fonts and colors, and is one undo step, or none when cancelled.
@MainActor
@Suite("Quick edit: my style")
struct QuickEditMyStyleTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
        let kits: BrandKitStore
        let preferences: FakeEditorPreferencesStore
        let take: Take
        let takes: TakeLibraryService
        let library: ScriptLibraryService
    }

    private static func kitsStore() -> BrandKitStore {
        let root = URL.temporaryDirectory.appending(path: "MyStyle-\(UUID().uuidString)", directoryHint: .isDirectory)
        return BrandKitStore(repository: LocalBrandKitRepository(directory: root.appending(path: "Kits")), directory: root.appending(path: "Kits"))
    }

    private func open(
        _ take: Take, takes: TakeLibraryService, library: ScriptLibraryService, kits: BrandKitStore, preferences: FakeEditorPreferencesStore
    ) async -> (QuickEditViewModel, ToastService) {
        let toast = ToastService()
        let root = URL.temporaryDirectory.appending(path: "MyStyleMedia-\(UUID().uuidString)", directoryHint: .isDirectory)
        let media = MediaLibraryStore(repository: LocalMediaLibraryRepository(directory: root), directory: root)
        let viewModel = QuickEditViewModel(
            take: take, takes: takes, library: library, editing: FakeTakeEditor(), drafts: FakeDraftStore(), toast: toast,
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            mediaLibrary: media, brandKits: kits, editorPreferences: preferences
        )
        await viewModel.prepare()
        return (viewModel, toast)
    }

    private func makeScenario(kits: BrandKitStore = Self.kitsStore(), edit: TakeEdit? = nil) async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 1)
        take.duration = 30
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let preferences = FakeEditorPreferencesStore()
        let (viewModel, toast) = await open(takes.takes[0], takes: takes, library: library, kits: kits, preferences: preferences)
        return Scenario(
            viewModel: viewModel, toast: toast, kits: kits, preferences: preferences, take: takes.takes[0], takes: takes, library: library
        )
    }

    private var brandBlue: OverlayColor { .custom(red: 0.118, green: 0.4, blue: 0.961) }

    /// A kit with fonts, colors, a text style and an Editing of long pauses, a tight gap, quiet music and strong Studio Voice.
    private func styleKit(newVideos: Bool) -> BrandKit {
        var kit = BrandKit(name: "Acme")
        kit.colors = [brandBlue]
        kit.titleFont = .anton
        kit.captionFont = .montserrat
        var look = TextLook()
        look.color = brandBlue
        kit.textStyle = BrandKitStyle(name: "Acme title", look: look)
        var editing = BrandKitEditing(of: TakeEdit(sourceDuration: 30, aspect: .portrait))
        editing.pauseThreshold = 1.2
        editing.pauseGap = .tight
        editing.music = MusicDefaults(volume: 0.25, duck: MusicDuck(depth: 18, pauses: .comesBack))
        editing.voiceEnhancement = .strong
        editing.noiseReduction = .strong
        kit.editing = editing
        kit.usesOnNewVideos = newVideos ? true : nil
        return kit
    }

    private func addTitleAndCaptions(_ viewModel: QuickEditViewModel) {
        viewModel.changeEdit { edit in
            var bold = CaptionCue(text: "Comidas de SP", start: 0.3, end: 2.3)
            bold.lineStyle = CaptionLineStyle(isEmphasized: true, size: .bigger)
            edit.captions = [bold, CaptionCue(text: "que são só pra turista.", start: 2.3, end: 4)]
            edit.showsCaptions = true
            var mine = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 1, end: 4))
            mine.text = "Three habits"
            mine.font = .dmSerif
            mine.color = .red
            mine.customized = [.font, .color]
            var plain = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 5, end: 8))
            plain.text = "Second"
            edit.texts = [mine, plain]
        }
    }

    // MARK: - New videos

    @Test func aNewVideoOpensInTheDefaultKitAndUndoTakesItOffThatVideoOnly() async throws {
        let kits = Self.kitsStore()
        kits.save(styleKit(newVideos: true))
        let scenario = await makeScenario(kits: kits)
        let viewModel = scenario.viewModel
        let kit = try #require(kits.newVideoKit)
        #expect(viewModel.edit.brandKit?.id == kit.id)
        #expect(viewModel.edit.textLook?.font == .anton)
        #expect(viewModel.edit.pauseThreshold == 1.2)
        #expect(viewModel.edit.newMusic?.volume == 0.25)
        // Studio Voice changes the sound: said in the toast.
        #expect(viewModel.edit.voiceEnhancement == .strong)
        #expect(scenario.toast.message == "Your style is on · Studio Voice changes the sound")
        #expect(scenario.toast.action?.title == "Undo")
        #expect(scenario.preferences.newVideoKitTakes.contains(scenario.take.id))
        // Undo: off this video; the kit is still the one new videos open in.
        scenario.toast.action?.perform()
        #expect(viewModel.edit.brandKit == nil)
        #expect(viewModel.edit.pauseThreshold == TakeEdit(sourceDuration: 30, aspect: .portrait).pauseThreshold)
        #expect(kits.newVideoKit?.id == kit.id)
        // Opening the same video again (nothing saved yet) doesn't put it back on.
        let (again, _) = await open(scenario.take, takes: scenario.takes, library: scenario.library, kits: kits, preferences: scenario.preferences)
        #expect(again.edit.brandKit == nil)
    }

    @Test func aVideoAlreadyEditedKeepsWhatItHas() async throws {
        let kits = Self.kitsStore()
        kits.save(styleKit(newVideos: true))
        var saved = TakeEdit(sourceDuration: 30, aspect: .portrait)
        saved.pauseThreshold = 0.5
        let scenario = await makeScenario(kits: kits, edit: saved)
        #expect(scenario.viewModel.edit.brandKit == nil)
        #expect(scenario.viewModel.edit.pauseThreshold == 0.5)
        #expect(scenario.toast.message == nil)
    }

    @Test func noKitForNewVideosLeavesANewVideoAsItIs() async {
        let kits = Self.kitsStore()
        kits.save(styleKit(newVideos: false))
        let scenario = await makeScenario(kits: kits)
        #expect(scenario.viewModel.edit.brandKit == nil)
        #expect(scenario.preferences.newVideoKitTakes.isEmpty)
    }

    @Test func onlyOneKitIsTheOneNewVideosOpenIn() throws {
        let kits = Self.kitsStore()
        let first = styleKit(newVideos: true)
        kits.save(first)
        var second = styleKit(newVideos: true)
        second.name = "Other"
        kits.save(second)
        #expect(kits.newVideoKit?.id == second.id)
        #expect(kits.kit(first.id)?.usesOnNewVideos == nil)
        // A copy is never the default; a kit put back after another took the place stays off.
        let copy = try #require(kits.duplicate(second.id))
        #expect(copy.usesOnNewVideos == nil)
        #expect(kits.newVideoKit?.id == second.id)
        let removed = try #require(kits.remove(second.id))
        var again = try #require(kits.kit(first.id))
        again.usesOnNewVideos = true
        kits.save(again)
        kits.restore(removed)
        #expect(kits.newVideoKit?.id == first.id)
        #expect(kits.kits.filter { $0.usesOnNewVideos == true }.count == 1)
    }

    // MARK: - Editing

    @Test func editingReadiesTheToolsAndCutsNothing() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let before = viewModel.edit
        let kit = styleKit(newVideos: false)
        viewModel.brand.apply(kit, parts: [.editing])
        #expect(viewModel.edit.pauseThreshold == 1.2)
        #expect(viewModel.edit.pauseGap == .tight)
        #expect(viewModel.edit.timeline == before.timeline)
        #expect(viewModel.edit.suggestions == before.suggestions)
        // Studio Voice wasn't chosen: the sound didn't change.
        #expect(viewModel.edit.voiceEnhancement == before.voiceEnhancement)
        #expect(viewModel.edit.noiseReduction == before.noiseReduction)
        // Music added now starts at the kit's level, going as far down under the voice.
        viewModel.audio.addMusic(ImportedAudio(fileName: "song.m4a", title: "Morning song", duration: 95))
        let music = try #require(viewModel.edit.music.first)
        #expect(music.volume == 0.25)
        #expect(music.duck == MusicDuck(depth: 18, pauses: .comesBack))
        #expect(scenario.toast.message?.hasSuffix("· 25%") == true)
        // Studio Voice, chosen, does change it.
        viewModel.brand.apply(kit, parts: [.studioVoice])
        #expect(viewModel.edit.voiceEnhancement == .strong)
        #expect(viewModel.edit.noiseReduction == .strong)
    }

    @Test func eachEditingPartSaysWhatItDoes() async throws {
        let scenario = await makeScenario()
        let changes = scenario.viewModel.brand.changes(for: styleKit(newVideos: false))
        let editing = try #require(changes.first { $0.part == .editing })
        #expect(editing.detail.contains("nothing is cut"))
        #expect(editing.detail.contains("25%"))
        let voice = try #require(changes.first { $0.part == .studioVoice })
        #expect(voice.detail.hasSuffix("the video's sound changes now"))
    }

    @Test func aKitFromThisVideoKeepsItsEditing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.changeEdit { $0.pauseThreshold = 0.9 }
        let made = viewModel.brand.kitFromThisVideo()
        #expect(made.editing?.pauseThreshold == 0.9)
        #expect(made.editing?.music.volume == MusicDefaults.standardVolume)
    }

    // MARK: - Hand-made changes (H)

    @Test func whatWasStyledByHandStaysUnlessTheCreatorAsks() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        addTitleAndCaptions(viewModel)
        let kit = styleKit(newVideos: false)
        // Fonts and a text style touch titles; only a caption style touches the lines' own looks.
        #expect(viewModel.brand.manualChanges(replacedBy: [.textStyle, .fonts]) == ManualStyleChanges(titles: 1, captionLines: 0))
        #expect(viewModel.brand.manualChanges(replacedBy: [.captionStyle]).captionLines == 1)
        viewModel.brand.apply(kit, parts: [.textStyle, .fonts])
        let mine = try #require(viewModel.edit.texts.first)
        let plain = try #require(viewModel.edit.texts.last)
        #expect(mine.font == .dmSerif)
        #expect(mine.color == .red)
        #expect(plain.font == .anton)
        #expect(plain.color == brandBlue)
        #expect(viewModel.edit.captions.first?.lineStyle?.size == .bigger)
        // Asked to: replaced too, still one undo step.
        viewModel.undo()
        viewModel.brand.apply(kit, parts: [.textStyle, .fonts], replacing: ReplacedManualChanges(titles: true, captionLines: false))
        #expect(viewModel.edit.texts.first?.font == .anton)
        #expect(viewModel.edit.texts.first?.color == brandBlue)
        #expect(viewModel.edit.texts.first?.text == "Three habits")
        viewModel.undo()
        #expect(viewModel.edit.texts.first?.font == .dmSerif)
        // A caption style keeps the lines' own looks, unless asked.
        var withCaptions = kit
        withCaptions.captionStyle = BrandKitStyle(
            name: "Acme captions", look: MyCaptionStyle(settings: VideoTemplate.story.captionSettings, animation: VideoTemplate.story.captionReveal)
        )
        viewModel.brand.apply(withCaptions, parts: [.captionStyle])
        #expect(viewModel.edit.captions.first?.lineStyle?.size == .bigger)
        viewModel.undo()
        viewModel.brand.apply(withCaptions, parts: [.captionStyle], replacing: ReplacedManualChanges(titles: false, captionLines: true))
        #expect(viewModel.edit.captions.first?.lineStyle?.isPlain ?? true)
        #expect(viewModel.edit.captions.map(\.text) == ["Comidas de SP", "que são só pra turista."])
    }

    // MARK: - Templates

    @Test func aTemplateIsTriedOnAndCancellingLeavesNoStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        addTitleAndCaptions(viewModel)
        let before = viewModel.edit
        let steps = viewModel.document.history.past.count
        viewModel.tryVideoTemplate(.boldHook)
        #expect(viewModel.templateTrial?.template == .boldHook)
        #expect(viewModel.edit.captionCollection?.theme == VideoTemplate.boldHook.captionTheme)
        #expect(viewModel.templateTrial?.manual == ManualStyleChanges(in: EditSnapshot(before), replacing: ManualStyleChanges.wholeLook, touchesCaptions: true))
        #expect(viewModel.templateTrial?.lines.first?.detail == "Lines, timing and place stay")
        viewModel.dropVideoTemplate()
        #expect(viewModel.templateTrial == nil)
        #expect(viewModel.edit == before)
        #expect(viewModel.document.history.past.count == steps)
    }

    @Test func aTemplateKeptIsOneStepAndKeepsHandMadeLooks() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        addTitleAndCaptions(viewModel)
        let before = viewModel.edit
        let steps = viewModel.document.history.past.count
        viewModel.tryVideoTemplate(.story)
        #expect(viewModel.edit.texts.first?.font == .dmSerif)
        #expect(viewModel.edit.captions.first?.lineStyle?.size == .bigger)
        // A switch: the template goes on again from how the video was, replacing those too.
        viewModel.setTemplateReplacing(ReplacedManualChanges(titles: true, captionLines: true))
        #expect(viewModel.edit.texts.first?.color != .red)
        #expect(viewModel.edit.captions.first?.lineStyle == nil)
        #expect(viewModel.edit.captions.map(\.text) == before.captions.map(\.text))
        viewModel.keepVideoTemplate()
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(scenario.toast.action?.title == "Undo")
        viewModel.undo()
        #expect(viewModel.edit.texts == before.texts)
        #expect(viewModel.edit.captions == before.captions)
        #expect(viewModel.edit.captionCollection == before.captionCollection)
    }

    @Test func aTemplateOnAVideoWithAKitKeepsTheKitsFontsAndColors() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.changeEdit { edit in
            edit.captions = [CaptionCue(text: "Real talk", start: 1, end: 2)]
            edit.showsCaptions = true
            var title = TextOverlay(role: .title, look: TextLook(), preset: nil, span: TimeSpan(start: 1, end: 4))
            title.text = "Three habits"
            edit.texts = [title]
        }
        viewModel.brand.apply(styleKit(newVideos: false), parts: [.textStyle, .fonts, .colors])
        #expect(viewModel.edit.captionCollection?.face == .montserrat)
        viewModel.tryVideoTemplate(.boldHook)
        let lines = try #require(viewModel.templateTrial?.lines)
        #expect(lines.allSatisfy { $0.id == "hook" || $0.detail.contains("keeps Acme's fonts and colors") })
        viewModel.keepVideoTemplate()
        #expect(viewModel.edit.captionCollection?.theme == VideoTemplate.boldHook.captionTheme)
        #expect(viewModel.edit.captionCollection?.face == .montserrat)
        #expect(viewModel.edit.texts.first?.font == .anton)
        #expect(viewModel.edit.texts.first?.color == brandBlue)
        #expect(viewModel.edit.textLook?.font == .anton)
        #expect(viewModel.edit.brandKit?.name == "Acme")
    }

    // MARK: - Saved files from before

    @Test func kitsAndEditsSavedBeforeReadAsTheyWere() throws {
        var kit = styleKit(newVideos: true)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(kit)) as? [String: Any])
        object["editing"] = nil
        object["usesOnNewVideos"] = nil
        let old = try JSONDecoder().decode(BrandKit.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.editing == nil)
        #expect(old.usesOnNewVideos == nil)
        #expect(!old.has(.editing))
        kit.editing = nil
        kit.usesOnNewVideos = nil
        #expect(old.name == kit.name)
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        edit.newMusic = MusicDefaults(volume: 0.3, duck: .standard)
        var saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved)).newMusic?.volume == 0.3)
        saved["newMusic"] = nil
        #expect(try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: saved)).newMusic == nil)
    }
}
