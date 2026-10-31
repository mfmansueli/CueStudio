//
//  ScriptFontSheetCaptureTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Contact sheets for the owner: every caption style, every text family, a few cover faces and every library family, in
/// English, Japanese, Chinese (simplified and traditional), Korean, Arabic, Hindi, Thai and Vietnamese, drawn the way the
/// preview and the export draw them (the caption with its third word being said). Opt-in:
/// `TEST_RUNNER_CUE_SCRIPT_FONT_SHEET=<folder on the Mac>`. With `TEST_RUNNER_CUE_SCRIPT_FONT_PACKS=<folder>` (the files
/// `tools/fonts/make_manifest.py` downloaded, named "<family>__<file>"), the library's files go through the store (checked,
/// registered) first: `captions-system.png` is before them, `captions-library.png`, `texts.png`, `covers.png` and
/// `library.png` after. `ScriptFontDeviceTests` draws the same sheets on an iPhone, with the files really downloaded.
@MainActor
@Suite("Script font sheets capture", .enabled(if: ProcessInfo.processInfo.environment["CUE_SCRIPT_FONT_SHEET"] != nil))
struct ScriptFontSheetCaptureTests {
    /// Each language with how its creator reads Chinese characters (their languages decide it in the app).
    static let languages: [(code: String, words: [String], han: WritingScript)] = [
        ("en", ["Day", "1", "of", "my", "trip"], .chineseSimplified),
        ("ja", ["Day", "1", "の", "朝", "ごはん"], .japanese),
        ("zh-Hans", ["旅行", "第一", "天", "早上"], .chineseSimplified),
        ("zh-Hant", ["這是", "我的", "第一", "天"], .chineseTraditional),
        ("ko", ["여행", "첫날", "아침"], .chineseSimplified),
        ("ar", ["اليوم", "الأول", "من", "رحلتي"], .chineseSimplified),
        ("hi", ["मेरी", "यात्रा", "का", "पहला", "दिन"], .chineseSimplified),
        ("th", ["วันแรก", "ของ", "การ", "เดินทาง"], .chineseSimplified),
        ("vi", ["Ngày", "đầu", "tiên", "của", "chuyến", "đi"], .chineseSimplified),
    ]

    private let frame = CGSize(width: 1080, height: 1920)
    private let tile = CGSize(width: 420, height: 190)

    /// The library's files from a folder on the Mac, as a download would bring them.
    private struct FolderSource: FontPackSource {
        let folder: URL
        let packs: [String: String]

        func data(for file: FontPack.File, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
            let id = packs[file.file] ?? ""
            return try Data(contentsOf: folder.appending(path: "\(id)__\(file.file)"))
        }
    }

    @Test func drawTheSheets() async throws {
        let environment = ProcessInfo.processInfo.environment
        let folder = URL(fileURLWithPath: try #require(environment["CUE_SCRIPT_FONT_SHEET"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let reading = FontPackRegistry.shared.hanReading
        defer { FontPackRegistry.shared.hanReading = reading }
        let themes = CaptionTheme.allCases.filter { CaptionStyleSpec.spec(for: $0, version: CaptionStyleSpec.currentVersion).motion != nil }
        try save(captionSheet(themes), to: folder.appending(path: "captions-system.png"))

        if let packs = environment["CUE_SCRIPT_FONT_PACKS"] {
            let manifest = FontPackManifest.bundled
            let names = Dictionary(manifest.packs.flatMap { pack in pack.files.map { ($0.file, pack.id) } }) { first, _ in first }
            let store = FontPackStore(
                source: FolderSource(folder: URL(fileURLWithPath: packs), packs: names),
                directory: URL.temporaryDirectory.appending(path: "SheetPacks-\(UUID().uuidString)", directoryHint: .isDirectory)
            )
            for pack in manifest.packs {
                for weight in pack.weights { _ = await store.request(pack, weight: weight).value }
            }
            let failed = manifest.packs.filter { store.state(of: $0) != .ready }.map(\.id)
            #expect(failed.isEmpty, "not registered: \(failed)")
            try save(captionSheet(themes), to: folder.appending(path: "captions-library.png"))
            try save(librarySheet(manifest), to: folder.appending(path: "library.png"))
        }
        try save(textSheet(), to: folder.appending(path: "texts.png"))
        try save(coverSheet(), to: folder.appending(path: "covers.png"))
    }

    // MARK: - Sheets

    func captionSheet(_ themes: [CaptionTheme]) -> UIImage {
        sheet(rows: themes.map(\.label), cells: themes.map { theme in
            Self.languages.map { language in
                FontPackRegistry.shared.hanReading = language.han
                return caption(theme, words: language.words)
            }
        })
    }

    func textSheet() -> UIImage {
        let faces = TextOverlayFont.editorFonts
        return sheet(rows: faces.map(\.label), cells: faces.map { face in
            Self.languages.map { language in
                FontPackRegistry.shared.hanReading = language.han
                var text = TextOverlay(role: .title, look: TypePreset.allCases[0].look(for: .title), preset: nil, span: TimeSpan(start: 0, end: 2))
                text.text = CaptionText.joined(language.words)
                text.font = face
                text.weight = face.weights.contains(.heavy) ? .heavy : face.weights.last ?? .regular
                text.effect = nil
                return TextOverlayRenderer.image(for: text, frameWidth: frame.width)
            }
        })
    }

    private func coverSheet() -> UIImage {
        let fonts = [CoverFont.anton, .grotesk, .serif, .system, CoverFont(.caveat), CoverFont(.rubik), CoverFont(.bangers)]
        let size = CGSize(width: 540, height: 720)
        let picture = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.2, green: 0.25, blue: 0.4, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return sheet(rows: fonts.map(\.label), cells: fonts.map { font in
            Self.languages.map { language in
                FontPackRegistry.shared.hanReading = language.han
                var composition = CoverComposition(template: .educational)
                composition.title.font = font
                return CoverCompositionRenderer.image(
                    title: CaptionText.joined(language.words), composition: composition, pictures: .init(main: picture), size: size, cutout: nil
                )
            }
        }, tile: CGSize(width: 270, height: 360))
    }

    private func librarySheet(_ manifest: FontPackManifest) -> UIImage {
        let samples: [WritingScript: String] = [
            .japanese: "Day 1 の朝ごはん", .chineseSimplified: "旅行第一天早上", .chineseTraditional: "這是我的第一天",
            .korean: "여행 첫날 아침", .arabic: "اليوم الأول من رحلتي", .devanagari: "मेरी यात्रा का पहला दिन", .thai: "วันแรกของการเดินทาง",
        ]
        let size = CGSize(width: 1500, height: 74)
        let rows = manifest.packs.map(\.family)
        let cells: [[UIImage?]] = manifest.packs.map { pack in
            FontPackRegistry.shared.hanReading = pack.script == .chineseTraditional ? .chineseTraditional : .chineseSimplified
            return [pack.weights.first, pack.weights.last].map { weight in
                let text = samples[pack.script] ?? ""
                let font = TextFont.font(.pack(pack.id), weight: weight ?? .regular, size: 48, text: text)
                return UIGraphicsImageRenderer(size: size).image { _ in
                    (text as NSString).draw(at: CGPoint(x: 8, y: 4), withAttributes: [.font: font, .foregroundColor: UIColor.white])
                }
            }
        }
        return sheet(rows: rows, cells: cells, tile: CGSize(width: 750, height: 37), columns: ["lightest", "heaviest"])
    }

    // MARK: - Drawing

    /// The caption at its third word, as the compositor's cache draws it.
    private func caption(_ theme: CaptionTheme, words: [String]) -> UIImage? {
        let cue = CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4)
        })
        let settings = CaptionSettings(theme: theme)
        let states = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .middle, frame: frame, animation: settings.spec.animation)
        guard let state = states.first(where: { $0.span?.contains(1.2) == true }), let lazy = state.lazyText, let collection = lazy.collection else {
            return nil
        }
        return CaptionCollectionRenderer.image(lazy.text.text, settings: collection, frame: frame, emphasis: lazy.emphasis, markup: lazy.markup)
    }

    func sheet(rows: [String], cells: [[UIImage?]], tile: CGSize? = nil, columns: [String]? = nil) -> UIImage {
        let tile = tile ?? self.tile
        let header: [String] = columns ?? Self.languages.map(\.code)
        let gutter: CGFloat = 230, top: CGFloat = 50, gap: CGFloat = 6
        let size = CGSize(width: gutter + CGFloat(header.count) * (tile.width + gap), height: top + CGFloat(rows.count) * (tile.height + gap))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.1, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let label: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: UIColor.white]
            for (column, name) in header.enumerated() {
                (name as NSString).draw(at: CGPoint(x: gutter + CGFloat(column) * (tile.width + gap) + 8, y: 12), withAttributes: label)
            }
            for (row, name) in rows.enumerated() {
                let y = top + CGFloat(row) * (tile.height + gap)
                (name as NSString).draw(in: CGRect(x: 10, y: y + 8, width: gutter - 16, height: tile.height - 8), withAttributes: label)
                for (column, image) in cells[row].enumerated() {
                    let cell = CGRect(x: gutter + CGFloat(column) * (tile.width + gap), y: y, width: tile.width, height: tile.height)
                    UIColor(red: 0.3, green: 0.34, blue: 0.42, alpha: 1).setFill()
                    context.fill(cell)
                    guard let image, image.size.width > 0, image.size.height > 0 else { continue }
                    let scale = min(cell.width / image.size.width, cell.height / image.size.height, 1)
                    let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(in: CGRect(x: cell.midX - drawn.width / 2, y: cell.midY - drawn.height / 2, width: drawn.width, height: drawn.height))
                }
            }
        }
    }

    func save(_ image: UIImage, to url: URL) throws {
        try #require(image.pngData()).write(to: url)
    }
}
