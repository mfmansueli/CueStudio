//
//  ScriptFontDeviceTests.swift
//  Cue StudioTests
//

import AVFAudio
import CoreImage
import CoreText
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The script libraries on this iPhone, where the Simulator can't tell, with no one at the phone:
/// - the system faces `ScriptTypeMap` names (Hiragino, PingFang, Apple SD Gothic Neo, Kohinoor, Thonburi) exist here under those
///   names and draw their script;
/// - every file of every family really downloaded from the manifest's host, checked, registered and drawing its script, with the
///   time and speed of each;
/// - an export's wait for a large CJK file (`VideoExportService.fontWait`): how long it really waits, never longer;
/// - the memory several CJK files take once registered and drawn;
/// - captions as a creator gets them: a recording in each language (Apple's system voice, and a person reading FLEURS) is
///   captioned by this iPhone's speech recognition like a take, and the lines it gives are drawn in every caption style with its
///   motion (three moments of the words being said), in every text family and with the six text effects (three moments of their
///   way in), with the library's files downloaded first. Every letter has a face, and a script's letters are drawn in its library
///   face or in the style's own. The sheets are saved in the app's Documents (`ScriptFontSheets`) to be copied back.
///
/// Opt-in and on a device, on the network: `CUE_DEVICE=<iPhone> scripts/test.sh device ScriptFontDeviceTests`
/// (`TEST_RUNNER_CUE_FONT_E2E=1`). Fonts are downloaded into folders of their own and deleted after, never the app's library. A
/// language this iPhone can't caption is *not validated*, never passed.
@MainActor
@Suite(
    "Script fonts on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_FONT_E2E"] != nil)
)
struct ScriptFontDeviceTests {
    private let manifest = FontPackManifest.bundled
    private static let frame = CGSize(width: 1080, height: 1920)
    /// Where the sheets go, in the app's Documents.
    private static let sheets = URL.documentsDirectory.appending(path: "ScriptFontSheets", directoryHint: .isDirectory)

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// A store downloading into a folder of its own. Each test ends with `eraseAll()`, which unregisters the files before
    /// deleting them: a face left registered from a deleted file shadows the next download of that name, and every letter of
    /// it is then drawn as a box.
    private func store(registry: FontPackRegistry) -> (FontPackStore, URL) {
        let folder = URL.temporaryDirectory.appending(path: "FontPacksDevice-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (FontPackStore(manifest: manifest, source: GoogleFontsPackSource(), directory: folder, registry: registry), folder)
    }

    /// `font` has a glyph for every letter of `text`.
    private static func draws(_ text: String, in font: UIFont) -> Bool {
        let ctFont = font as CTFont
        return text.unicodeScalars.allSatisfy { scalar in
            let units = Array(String(scalar).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: units.count)
            return CTFontGetGlyphsForCharacters(ctFont, units, &glyphs, units.count) && glyphs.allSatisfy { $0 != 0 }
        }
    }

    private static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }

    private static func megabytes(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    /// Draws `text` large in `font`, as a caption would, so the glyphs are really loaded.
    private static func render(_ text: String, in font: UIFont) {
        let size = CGSize(width: 1080, height: 400)
        _ = UIGraphicsImageRenderer(size: size).image { _ in
            (text as NSString).draw(in: CGRect(origin: .zero, size: size), withAttributes: [.font: font])
        }
    }

    // MARK: - System faces

    @Test func everySystemFaceTheMapNamesIsOnThisIPhoneAndDrawsItsScript() {
        var missing: Set<String> = []
        var wrong: Set<String> = []
        var checked: Set<String> = []
        for script in WritingScript.allCases {
            for character in TypeCharacter.allCases {
                for weight in TextOverlayWeight.allCases {
                    for name in ScriptTypeMap.systemFaces(for: character, in: script, weight: weight) where !checked.contains("\(script)|\(name)") {
                        checked.insert("\(script)|\(name)")
                        guard let font = UIFont(name: name, size: 40) else {
                            missing.insert(name)
                            continue
                        }
                        if !Self.draws(script.sample, in: font) { wrong.insert("\(name) (\(script.rawValue))") }
                    }
                }
            }
        }
        print("SYSTEM FACES: \(checked.count) checked · missing: \(missing.sorted()) · can't draw their script: \(wrong.sorted())")
        #expect(missing.isEmpty, "Faces this iPhone doesn't have under that name: \(missing.sorted())")
        #expect(wrong.isEmpty, "Faces that don't draw their script: \(wrong.sorted())")
    }

    // MARK: - Real downloads

    /// Every file of every family of `script`, from the internet as a creator's iPhone gets it.
    @Test(arguments: WritingScript.allCases)
    func everyFamilyOfTheScriptDownloadsChecksRegistersAndDraws(_ script: WritingScript) async {
        KeepScreenAwake.enable()
        let registry = FontPackRegistry()
        let (store, _) = store(registry: registry)
        defer { store.eraseAll() }
        var lines: [String] = []
        var total = 0
        let started = uptime
        for pack in manifest.packs(for: script) {
            // The files the app can ask for: each weight's (`FontPack.file(for:)`); a cut no weight picks is never downloaded.
            var files: [(file: FontPack.File, weight: TextOverlayWeight)] = []
            for weight in TextOverlayWeight.allCases where !files.contains(where: { $0.file.file == pack.file(for: weight).file }) {
                files.append((pack.file(for: weight), weight))
            }
            for (file, weight) in files {
                let start = uptime
                let arrived = await store.request(pack, weight: weight).value
                let seconds = uptime - start
                #expect(arrived, "\(pack.family) \(file.file) didn't arrive")
                let font = UIFont(name: file.postScriptName, size: 40)
                #expect(font != nil, "\(pack.family) \(file.file) isn't registered as \(file.postScriptName)")
                #expect(font.map { Self.draws(script.sample, in: $0) } == true, "\(pack.family) \(file.file) doesn't draw \(script.sample)")
                total += file.bytes
                let speed = seconds > 0 ? Double(file.bytes) / 1_048_576 / seconds : 0
                lines.append(String(format: "  %@ %@ · %@ in %.2f s (%.1f MB/s)", pack.family, file.file, Self.megabytes(file.bytes), seconds, speed))
            }
        }
        let failed = manifest.packs(for: script).filter { store.state(of: $0) != .ready }.map(\.family)
        #expect(failed.isEmpty, "\(script.rawValue): not ready \(failed)")
        print("DOWNLOADS \(script.rawValue): \(Self.megabytes(total)) in \(String(format: "%.1f", uptime - started)) s\n" + lines.joined(separator: "\n"))
    }

    // MARK: - The export's wait

    @Test func anExportWaitsForALargeCJKFileAtMostItsFontWait() async {
        let registry = FontPackRegistry()
        let (store, _) = store(registry: registry)
        defer { store.eraseAll() }
        let cjk: [WritingScript] = [.japanese, .chineseSimplified, .chineseTraditional, .korean]
        guard let pack = manifest.packs.filter({ cjk.contains($0.script) }).max(by: { $0.file(for: .bold).bytes < $1.file(for: .bold).bytes }) else {
            Issue.record("No CJK family in the manifest")
            return
        }
        let file = pack.file(for: .bold)
        let wait = VideoExportService.fontWait
        let need = FontPackNeed(packID: pack.id, weight: .bold)
        let start = uptime
        // What an export does: ask for the families its words need, then wait for them at most `fontWait`.
        store.request([need])
        await store.awaitDownloads([need], timeout: wait)
        let waited = uptime - start
        let arrived = store.state(of: pack, weight: .bold) == .ready
        print(String(
            format: "EXPORT WAIT: %@ %@ (%@) · waited %.2f s of %.0f s · %@", pack.family, file.file, Self.megabytes(file.bytes), waited,
            Double(wait.components.seconds), arrived ? "arrived in time" : "not yet: the export goes with the system's faces"
        ))
        #expect(waited <= Double(wait.components.seconds) + 2, "The export waited \(waited) s")
        // Whatever the wait gave, the download goes on and lands.
        if !arrived { _ = await store.request(pack, weight: .bold).value }
        #expect(store.state(of: pack, weight: .bold) == .ready)
    }

    // MARK: - Memory

    @Test func severalCJKFilesRegisteredAndDrawnTakeLittleMemory() async {
        let registry = FontPackRegistry()
        let (store, _) = store(registry: registry)
        defer { store.eraseAll() }
        let scripts: [WritingScript] = [.japanese, .chineseSimplified, .chineseTraditional, .korean]
        // Two families per script, the bold file of each: up to eight CJK files at once.
        let packs = scripts.flatMap { manifest.packs(for: $0).prefix(2) }
        for pack in packs { _ = await store.request(pack, weight: .bold).value }
        let before = Self.footprint()
        var drawn = 0
        var bytes = 0
        for pack in packs {
            guard let face = registry.face(of: pack, weight: .bold), let font = UIFont(name: face.postScriptName, size: 96) else { continue }
            Self.render(String(repeating: pack.script.sample + " ", count: 12), in: font)
            drawn += 1
            bytes += face.file.bytes
        }
        let grown = Self.footprint() - before
        print(
            "MEMORY: \(drawn) CJK files (\(Self.megabytes(bytes)) on disk) drawn · footprint grew \(Self.megabytes(grown))"
                + " · now \(Self.megabytes(Self.footprint()))"
        )
        #expect(drawn == packs.count)
        // Core Text maps the files instead of reading them: drawing them must not cost their size in memory.
        #expect(grown < bytes, "Drawing \(Self.megabytes(bytes)) of fonts grew the footprint by \(Self.megabytes(grown))")
    }

    // MARK: - Captions from speech, styles and motion

    nonisolated static let spokenLanguages: [CueLanguage] = [
        .japanese, .chineseSimplified, .chineseTraditional, .korean, .arabic, .hindi, .thai, .vietnamese,
    ]

    @Test(arguments: spokenLanguages)
    func captionsHeardInTheLanguageDrawInEveryStyleWithTheirMotion(_ language: CueLanguage) async throws {
        KeepScreenAwake.enable()
        try FileManager.default.createDirectory(at: Self.sheets, withIntermediateDirectories: true)
        let han = WritingScript.hanReading(for: [language])
        let reading = FontPackRegistry.shared.hanReading
        FontPackRegistry.shared.hanReading = han
        defer { FontPackRegistry.shared.hanReading = reading }

        // The recordings: the system voice, and the first person reading FLEURS in this language.
        var samples = [try SpeechSample.synthetic(of: language)]
        if let person = try SpeechSample.human().first(where: { $0.language == language }) { samples.append(person) }
        var cues: [(label: String, cue: CaptionCue)] = []
        for sample in samples {
            let transcript: TakeTranscript
            do {
                transcript = try await CaptionTranscriber.transcript(in: sample.url, language: .language(language), script: sample.script)
            } catch let reason as SpeechUnavailableReason {
                print("SCRIPT FONT CAPTIONS \(language.rawValue): NOT VALIDATED · \(reason.captionMessage)")
                try Test.cancel("\(language.rawValue) not validated: \(reason.captionMessage)")
            }
            let heard = transcript.words.map { CaptionWord(text: $0.text, start: $0.start, end: $0.end, isEstimated: $0.isEstimated) }
            let lines = CaptionBuilder.captions(heard: heard, script: sample.script, language: language)
            print("SCRIPT FONT HEARD \(language.rawValue) \(sample.voice.rawValue): " + heard.prefix(12).map {
                String(format: "%@ %.2f–%.2f", $0.text, $0.start, $0.end)
            }.joined(separator: " | "))
            let spelled = CaptionBuilder.attachingMarks(CaptionBuilder.aligned(heard: heard, script: sample.script, language: language))
            print("SCRIPT FONT SPELLED \(language.rawValue) \(sample.voice.rawValue): " + spelled.prefix(12).map(\.text).joined(separator: " | "))
            #expect(!lines.isEmpty, "\(sample.label): no caption heard")
            if let line = lines.first(where: { $0.words.count >= 3 }) ?? lines.first { cues.append((sample.voice.rawValue, line)) }
        }
        guard !cues.isEmpty else { return }

        // The library's files these words need, in every style, downloaded as an export would ask for them.
        let themes = CaptionTheme.allCases.filter { CaptionStyleSpec.spec(for: $0, version: CaptionStyleSpec.currentVersion).motion != nil }
        let faces = TextOverlayFont.editorFonts
        var needs = Set<FontPackNeed>()
        for (_, cue) in cues {
            for theme in themes {
                let spec = CaptionStyleSpec.spec(for: theme, version: CaptionStyleSpec.currentVersion)
                needs.formUnion(FontPackNeeds.needs(caption: spec, text: cue.text, han: han))
            }
            for face in faces { needs.formUnion(FontPackNeeds.needs(face: face, weight: Self.weight(of: face), text: cue.text, han: han)) }
            for preset in TypePreset.effectPresets {
                let text = Self.effectText(preset, words: cue.text)
                needs.formUnion(FontPackNeeds.needs(face: text.font, weight: text.weight, text: cue.text, han: han))
            }
        }
        let (store, folder) = store(registry: .shared)
        defer {
            store.eraseAll()
            try? FileManager.default.removeItem(at: folder)
        }
        let downloading = uptime
        store.request(needs)
        await store.awaitDownloads(needs, timeout: .seconds(200))
        let missing = needs.filter { need in manifest.pack(need.packID).map { store.state(of: $0, weight: need.weight) != .ready } ?? true }
        #expect(missing.isEmpty, "\(language.rawValue): not downloaded \(missing.map(\.packID).sorted())")
        let families = Set(needs.map(\.packID)).sorted()
        print("SCRIPT FONT CAPTIONS \(language.rawValue): \(needs.count) files of \(families) in \(String(format: "%.1f", uptime - downloading)) s")

        // Every letter has a face, and a script's letters are in the library's face or the style's own.
        var problems: [String] = []
        for (label, cue) in cues {
            print("SCRIPT FONT CAPTIONS \(language.rawValue) \(label): “\(cue.text)”")
            for theme in themes {
                let spec = CaptionStyleSpec.spec(for: theme, version: CaptionStyleSpec.currentVersion)
                let font = CaptionFont.font(spec: spec, size: 60, text: cue.text)
                problems += check(cue.text, font: font, needs: FontPackNeeds.needs(caption: spec, text: cue.text, han: han), what: "caption \(theme)")
                // A mark TextKit pins to a line's edge is drawn nowhere (the dot of "हैं" ending a line).
                if let layout = CaptionCollectionRenderer.layout(cue.text, settings: CaptionSettings(theme: theme), frame: Self.frame),
                   CaptionCollectionRenderer.pinsAMark(layout.manager, in: layout.container) {
                    problems.append("caption \(theme): a mark at a line's end isn't drawn")
                }
            }
            for face in faces {
                let font = TextFont.font(face, weight: Self.weight(of: face), size: 60, text: cue.text)
                let needs = FontPackNeeds.needs(face: face, weight: Self.weight(of: face), text: cue.text, han: han)
                problems += check(cue.text, font: font, needs: needs, what: "text \(face)")
            }
            for preset in TypePreset.effectPresets {
                problems += try checkEffect(preset, words: cue.text, language: language)
            }
        }
        print("SCRIPT FONT CAPTIONS \(language.rawValue): \(problems.isEmpty ? "every letter in its face" : problems.joined(separator: "\n  "))")
        #expect(problems.isEmpty, "\(language.rawValue): \(problems.count) problems")

        // The sheets: each style at three moments of its words being said, each family, each effect at three moments of its way in.
        let sheet = ScriptFontSheetCaptureTests()
        let cue = cues[0].cue
        let moments = Self.moments(of: cue)
        try sheet.save(sheet.sheet(
            rows: themes.map(\.label), cells: themes.map { theme in moments.map { caption(theme, cue: cue, at: $0) } },
            columns: moments.indices.map { "word \($0 == 0 ? "first" : $0 == 1 ? "middle" : "last")" }
        ), to: Self.sheets.appending(path: "captions-\(language.rawValue).png"))
        try sheet.save(sheet.sheet(
            rows: faces.map(\.label), cells: faces.map { face in cues.map { textImage(face, words: $0.cue.text) } }, columns: cues.map(\.label)
        ), to: Self.sheets.appending(path: "texts-\(language.rawValue).png"))
        let presets = TypePreset.effectPresets
        try sheet.save(sheet.sheet(
            rows: presets.map(\.rawValue), cells: try presets.map { try effectFrames($0, words: cue.text) }, columns: ["30%", "60%", "in place"]
        ), to: Self.sheets.appending(path: "effects-\(language.rawValue).png"))
        if cues.count > 1 {
            let person = cues[1].cue
            let personMoments = Self.moments(of: person)
            try sheet.save(sheet.sheet(
                rows: themes.map(\.label), cells: themes.map { theme in personMoments.map { caption(theme, cue: person, at: $0) } },
                columns: ["first", "middle", "last"]
            ), to: Self.sheets.appending(path: "captions-\(language.rawValue)-person.png"))
        }
    }

    // MARK: - Checking

    /// The letters of `text` outside Latin, each with the face that draws it; a problem for a letter with no face, or a script's
    /// letter drawn in neither the library's face nor the style's own.
    private func check(_ text: String, font: UIFont, needs: Set<FontPackNeed>, what: String) -> [String] {
        let library = Set(needs.compactMap { need in
            manifest.pack(need.packID).flatMap { FontPackRegistry.shared.face(of: $0, weight: need.weight)?.postScriptName }
        })
        var problems: [String] = []
        for run in Self.drawnRuns(text, font: font) {
            if run.font.contains("LastResort") || run.missingGlyphs || !run.fileExists {
                problems.append("\(what): “\(run.text)” has no face (\(run.font)\(run.fileExists ? "" : ", its file is gone"))")
                continue
            }
            let isScript = run.text.unicodeScalars.contains { scalar in WritingScript.allCases.contains { $0.contains(scalar) } }
            guard isScript, !library.isEmpty, !library.contains(run.font) else { continue }
            // A variable family is drawn at the weight under its instance's name ("Cairo-Regular_Bold"): the family says it.
            let family = run.family
            let libraryFamilies = Set(library.compactMap { UIFont(name: $0, size: 10)?.familyName })
            if family != font.familyName, !libraryFamilies.contains(family) {
                problems.append("\(what): “\(run.text)” in \(run.font), not the library's \(library.sorted())")
            }
        }
        return problems
    }

    private struct DrawnRun {
        let text: String
        let font: String
        let family: String
        let missingGlyphs: Bool
        let fileExists: Bool
    }

    /// Each run of `text` laid out in `font`, as drawn: the face, whether a glyph is missing (.notdef), and whether the face's
    /// file is still there (a face registered from a file since deleted draws boxes).
    private static func drawnRuns(_ text: String, font: UIFont) -> [DrawnRun] {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let string = text as NSString
        return (CTLineGetGlyphRuns(line) as? [CTRun] ?? []).compactMap { run in
            let range = CTRunGetStringRange(run)
            let piece = string.substring(with: NSRange(location: range.location, length: range.length))
            guard !piece.allSatisfy(\.isWhitespace) else { return nil }
            guard let value = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] else { return nil }
            let runFont = value as! CTFont // swiftlint:disable:this force_cast
            var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            let url = CTFontCopyAttribute(runFont, kCTFontURLAttribute) as? URL
            // System faces live where the app can't look; a downloaded one must still be in its folder.
            let downloaded = url.map { !$0.path.hasPrefix("/System/") } ?? false
            return DrawnRun(
                text: piece, font: CTFontCopyPostScriptName(runFont) as String, family: CTFontCopyFamilyName(runFont) as String,
                missingGlyphs: glyphs.contains(0),
                fileExists: !downloaded || url.map { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) } ?? true
            )
        }
    }

    /// The effect's pieces have faces, and move as the script moves: by word where letters join (Arabic, Hindi, Thai), one
    /// character at a time in Japanese and Chinese.
    private func checkEffect(_ preset: TypePreset, words: String, language: CueLanguage) throws -> [String] {
        let text = Self.effectText(preset, words: words)
        let request = try #require(TextOverlayRenderer.effectRequest(
            for: text, frameWidth: Self.frame.width, widthFraction: TextOverlayRenderer.maxWidthFraction
        ))
        let layout = try #require(TextEffectCache.shared.layout(for: request))
        var problems: [String] = []
        let faceless = layout.pieces.flatMap(\.glyphs).filter { $0.glyph == 0 || (CTFontCopyPostScriptName($0.font) as String).contains("LastResort") }.count
        if faceless > 0 { problems.append("effect \(preset.rawValue): \(faceless) glyphs with no face") }
        if [.arabic, .hindi, .thai].contains(language), !layout.piecesAreWords {
            problems.append("effect \(preset.rawValue): letters move apart in a joined script")
        }
        if [.japanese, .chineseSimplified, .chineseTraditional].contains(language) {
            // Characters one by one; Headline moves words, the language's own (never the whole line as one).
            if preset == .headline {
                if layout.pieces.count < 2 { problems.append("effect headline: the whole line moves as one piece") }
            } else if layout.piecesAreWords {
                problems.append("effect \(preset.rawValue): characters move as words")
            }
        }
        if language == .thai, layout.pieces.count < 2 { problems.append("effect \(preset.rawValue): the whole line moves as one piece") }
        return problems
    }

    // MARK: - Drawing

    private static func weight(of face: TextOverlayFont) -> TextOverlayWeight {
        face.weights.contains(.heavy) ? .heavy : face.weights.last ?? .regular
    }

    private static func effectText(_ preset: TypePreset, words: String) -> TextOverlay {
        var text = TextOverlay(role: .title, look: preset.look(for: .title), preset: preset, span: TimeSpan(start: 0, end: 4))
        text.text = words
        return text
    }

    /// Times inside the first, the middle and the last word.
    private static func moments(of cue: CaptionCue) -> [TimeInterval] {
        guard let first = cue.words.first, let last = cue.words.last else { return [cue.start] }
        let middle = cue.words[cue.words.count / 2]
        return [first, middle, last].map { min($0.start + 0.05, $0.end) }
    }

    /// The caption at `time`, as the compositor's cache draws it.
    private func caption(_ theme: CaptionTheme, cue: CaptionCue, at time: TimeInterval) -> UIImage? {
        let settings = CaptionSettings(theme: theme)
        let states = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .middle, frame: Self.frame, animation: settings.spec.animation)
        guard let state = states.first(where: { $0.span?.contains(time) == true }) ?? states.first, let lazy = state.lazyText,
              let collection = lazy.collection else { return nil }
        return CaptionCollectionRenderer.image(lazy.text.text, settings: collection, frame: Self.frame, emphasis: lazy.emphasis, markup: lazy.markup)
    }

    private func textImage(_ face: TextOverlayFont, words: String) -> UIImage? {
        var text = TextOverlay(role: .title, look: TypePreset.allCases[0].look(for: .title), preset: nil, span: TimeSpan(start: 0, end: 2))
        text.text = words
        text.font = face
        text.weight = Self.weight(of: face)
        text.effect = nil
        return TextOverlayRenderer.image(for: text, frameWidth: Self.frame.width)
    }

    /// The effect 30% and 60% of its way in, and in place.
    private func effectFrames(_ preset: TypePreset, words: String) throws -> [UIImage?] {
        let text = Self.effectText(preset, words: words)
        let effect = try #require(text.effect)
        let request = try #require(TextOverlayRenderer.effectRequest(
            for: text, frameWidth: Self.frame.width, widthFraction: TextOverlayRenderer.maxWidthFraction
        ))
        let sprites = try #require(TextEffectCache.shared.sprites(for: request))
        let length = text.span.duration
        let entrance = TextEffectChoreography.timing(effect, length: length).entrance
        let context = CIContext(options: [.cacheIntermediates: false])
        return [entrance * 0.3, entrance * 0.6, length / 2].map { time in
            let image = TextEffectComposer.image(sprites, effect: effect, time: time, length: length)
            let extent = image.extent.isInfinite ? sprites.rest().extent : image.extent
            guard !extent.isEmpty, let cgImage = context.createCGImage(image, from: extent.integral) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
}
