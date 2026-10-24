//
//  CaptionCatalogCaptureTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The catalogue drawn the way the preview and the export draw it (`CaptionCollectionRenderer.overlays`, then the state on screen
/// through the compositor's cache) on a 1080 × 1920 frame over a bright and a dark picture: the line still, a word being said
/// and a word marked for emphasis. One strip per group and one with every style (opt-in:
/// `TEST_RUNNER_CUE_CAPTION_CATALOG=<folder on the Mac>`), for the owner to judge and for the contrast report.
@MainActor
@Suite("Caption catalogue capture", .enabled(if: ProcessInfo.processInfo.environment["CUE_CAPTION_CATALOG"] != nil))
struct CaptionCatalogCaptureTests {
    private let frame = CGSize(width: 1080, height: 1920)
    /// What the captions say, with "real" marked for emphasis.
    private static let words = ["Make", "it", "real,", "one", "take", "at", "a", "time."]
    private static let marked: Set<Int> = [2]
    /// "it" being said early on, then "take".
    private static let moments: [TimeInterval] = [0.62, 1.82]

    private var cue: CaptionCue {
        var cue = CaptionCue(words: Self.words.enumerated().map { index, word in
            CaptionWord(text: word, start: 0.2 + Double(index) * 0.4, end: 0.2 + Double(index) * 0.4 + 0.34)
        })
        cue.emphasis = Self.marked
        return cue
    }

    /// The caption on screen at `time`, drawn as the compositor draws it, and where it sits (top-left origin).
    private func caption(_ settings: CaptionSettings, at time: TimeInterval) throws -> (image: UIImage, rect: CGRect) {
        var blocks = [cue]
        if let format = settings.format {
            blocks = CaptionBlocking.blocks([cue], format: format, settings: settings, frame: frame)
        }
        let states = CaptionCollectionRenderer.overlays(blocks, settings: settings, position: .bottom, frame: frame)
        let state = try #require(states.first { $0.span?.contains(time) == true })
        let image = try #require(state.lazyText.flatMap(OverlayImageCache().image(for:)))
        let drawn = UIImage(cgImage: try #require(CIContext().createCGImage(image, from: image.extent)))
        let rect = CGRect(x: state.origin.x, y: frame.height - state.origin.y - state.size.height, width: state.size.width, height: state.size.height)
        return (drawn, rect)
    }

    /// A bright, busy daylight scene or a night one, each with a person in the middle.
    private func picture(light: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: frame, format: format).image { context in
            let colors = light
                ? [UIColor(red: 0.98, green: 0.96, blue: 0.9, alpha: 1), UIColor(red: 0.85, green: 0.9, blue: 0.97, alpha: 1)]
                : [UIColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1), UIColor(red: 0.16, green: 0.1, blue: 0.2, alpha: 1)]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: frame.height), options: [])
            }
            for index in 0..<60 {
                let x = CGFloat((index * 137) % 1080), y = CGFloat((index * 251) % 1920)
                (light ? UIColor(white: 1, alpha: 0.7) : UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.35)).setFill()
                UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 120, height: 60), cornerRadius: 12).fill()
            }
            (light ? UIColor(red: 0.55, green: 0.38, blue: 0.3, alpha: 1) : UIColor(red: 0.42, green: 0.3, blue: 0.26, alpha: 1)).setFill()
            UIBezierPath(ovalIn: CGRect(x: 390, y: 620, width: 300, height: 380)).fill()
            UIColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 240, y: 980, width: 600, height: 1000), cornerRadius: 260).fill()
        }
    }

    /// The bottom of the frame with the caption on it.
    private func cell(_ settings: CaptionSettings, at time: TimeInterval, over picture: UIImage) throws -> UIImage {
        let drawn = try caption(settings, at: time)
        let crop = CGRect(x: 0, y: 1120, width: 1080, height: 560)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: crop.size, format: format).image { _ in
            picture.draw(in: CGRect(origin: CGPoint(x: 0, y: -crop.minY), size: frame))
            drawn.image.draw(in: drawn.rect.offsetBy(dx: 0, dy: -crop.minY))
        }
    }

    private func sheet(_ themes: [CaptionTheme], pictures: [UIImage]) throws -> UIImage {
        let tile = CGSize(width: 540, height: 280), gutter: CGFloat = 230, gap: CGFloat = 6
        let columns = pictures.count * Self.moments.count
        let size = CGSize(width: gutter + CGFloat(columns) * (tile.width + gap), height: CGFloat(themes.count) * (tile.height + gap))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let cells = try themes.map { theme in
            try pictures.flatMap { picture in try Self.moments.map { try cell(CaptionSettings(theme: theme), at: $0, over: picture) } }
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let title: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: UIColor.white]
            let detail: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor(white: 0.85, alpha: 1)]
            for (row, theme) in themes.enumerated() {
                let y = CGFloat(row) * (tile.height + gap)
                (theme.label as NSString).draw(at: CGPoint(x: 12, y: y + 12), withAttributes: title)
                (theme.summary as NSString).draw(in: CGRect(x: 12, y: y + 56, width: gutter - 24, height: tile.height - 60), withAttributes: detail)
                for (column, image) in cells[row].enumerated() {
                    image.draw(in: CGRect(x: gutter + CGFloat(column) * (tile.width + gap), y: y, width: tile.width, height: tile.height))
                }
            }
        }
    }

    /// The styles whose word being said pops, at the instant it is biggest, on long words next to each other: it never touches
    /// them (`pop-check.jpg`).
    @Test func drawThePops() throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_CAPTION_CATALOG"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let words = ["Incredible", "transformations", "happen", "everywhere"]
        var cue = CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: 0.2 + Double(index) * 0.5, end: 0.2 + Double(index) * 0.5 + 0.45)
        })
        cue.emphasis = []
        let themes: [CaptionTheme] = [.spotlight, .bold, .comic, .reveal]
        // The landing's biggest step (after its first), for each word.
        let moments = words.indices.map { 0.2 + Double($0) * 0.5 + 0.06 }
        let picture = picture(light: true)
        let tile = CGSize(width: 540, height: 280)
        let size = CGSize(width: CGFloat(moments.count) * (tile.width + 6), height: CGFloat(themes.count) * (tile.height + 6))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let cells = try themes.map { theme in
            try moments.map { time -> UIImage in
                let states = CaptionCollectionRenderer.overlays([cue], settings: CaptionSettings(theme: theme), position: .bottom, frame: frame)
                let state = try #require(states.first { $0.span?.contains(time) == true })
                let image = try #require(state.lazyText.flatMap(OverlayImageCache().image(for:)))
                let drawn = UIImage(cgImage: try #require(CIContext().createCGImage(image, from: image.extent)))
                let rect = CGRect(x: state.origin.x, y: frame.height - state.origin.y - state.size.height, width: state.size.width, height: state.size.height)
                let crop = CGRect(x: 0, y: 1120, width: 1080, height: 560)
                return UIGraphicsImageRenderer(size: crop.size, format: format).image { _ in
                    picture.draw(in: CGRect(origin: CGPoint(x: 0, y: -crop.minY), size: frame))
                    drawn.draw(in: rect.offsetBy(dx: 0, dy: -crop.minY))
                }
            }
        }
        let sheet = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (row, images) in cells.enumerated() {
                for (column, image) in images.enumerated() {
                    image.draw(in: CGRect(x: CGFloat(column) * (tile.width + 6), y: CGFloat(row) * (tile.height + 6), width: tile.width, height: tile.height))
                }
            }
        }
        try #require(sheet.jpegData(compressionQuality: 0.86)).write(to: folder.appending(path: "pop-check.jpg"))
    }

    @Test func drawTheCatalogue() throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_CAPTION_CATALOG"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pictures = [picture(light: true), picture(light: false)]
        for category in CaptionCategory.allCases {
            let image = try sheet(CaptionTheme.themes(in: category), pictures: pictures)
            try #require(image.jpegData(compressionQuality: 0.86)).write(to: folder.appending(path: "catalog-\(category.rawValue).jpg"))
        }
        var lines = ["style,scene,words,said,marked"]
        let scenes: [(String, ColorContrast.RGB)] = [
            ("white", .init(red: 1, green: 1, blue: 1)), ("black", .init(red: 0, green: 0, blue: 0)), ("gray", .init(red: 0.5, green: 0.5, blue: 0.5)),
        ]
        for theme in CaptionTheme.catalog {
            for (name, scene) in scenes {
                let reading = try #require(CaptionContrastProbe.reading(CaptionSettings(theme: theme), over: scene))
                lines.append(String(format: "%@,%@,%.2f,%.2f,%.2f", theme.rawValue, name, reading.words, reading.lit, reading.emphasis))
            }
        }
        try lines.joined(separator: "\n").write(to: folder.appending(path: "contrast.csv"), atomically: true, encoding: .utf8)
    }
}
