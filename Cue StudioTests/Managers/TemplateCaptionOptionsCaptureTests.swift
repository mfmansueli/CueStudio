//
//  TemplateCaptionOptionsCaptureTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Each video template's captions as they are now next to other looks made only of what the collection already has (another
/// preset, the reveal, the highlight color, the size, a text preset's look copied onto the captions), drawn the way the preview
/// and the export draw them (`CaptionCollectionRenderer.overlays`, then `image` for the state on screen) on a 1080 × 1920 frame
/// over a light and a dark picture, with the word being said mid-line and later on. Strips to choose from (opt-in:
/// `TEST_RUNNER_CUE_CAPTION_OPTIONS=<folder on the Mac>`): `<template>.png` with the whole frames and `<template>-detail.png`
/// with the captions up close.
@MainActor
@Suite("Template caption options capture", .enabled(if: ProcessInfo.processInfo.environment["CUE_CAPTION_OPTIONS"] != nil))
struct TemplateCaptionOptionsCaptureTests {
    /// One look for a template's captions, built the way `applyVideoTemplate` builds the collection.
    struct Option {
        let name: String
        let theme: CaptionTheme
        let reveal: CaptionAnimation
        var accent: CaptionAccent?
        var size = 1.0
        var look: TypePreset?

        var settings: CaptionSettings {
            var settings = CaptionSettings(theme: theme)
            settings.followsWords = reveal.followsWords
            settings.accent = accent
            settings.sizeScale = size
            settings.customLook = look?.look(for: .caption)
            return settings
        }

        var detail: String {
            var parts = [theme.rawValue, reveal.rawValue, (accent ?? settings.spec.defaultAccent).rawValue]
            if size != 1 { parts.append("\(size)×") }
            if let look { parts.append("look \(look.rawValue)") }
            return parts.joined(separator: " · ")
        }
    }

    private let frame = CGSize(width: 1080, height: 1920)
    private static let words = ["Sua", "ideia", "merece", "ganhar", "vida."]
    /// "merece" being said, then "vida.".
    private static let moments: [(name: String, time: TimeInterval)] = [("“merece”", 1.2), ("“vida.”", 2.2)]

    private static func options(for template: VideoTemplate) -> [Option] {
        let current = Option(
            name: "current", theme: template.captionTheme, reveal: template.captionReveal, accent: template.captionAccent, size: template.captionSize,
            look: template.captionLook
        )
        let proposed: [Option] = switch template {
        case .boldHook: [
            Option(name: "A", theme: .impact, reveal: .box, accent: .yellow, size: 1.25),
            Option(name: "B", theme: .impact, reveal: .highlight, accent: .yellow, size: 1.35),
            Option(name: "C", theme: .cue, reveal: .highlight, accent: .yellow, size: 1.35),
            Option(name: "D", theme: .pop, reveal: .highlight, accent: .yellow, size: 1.2),
            Option(name: "E", theme: .cue, reveal: .highlight, accent: .yellow, size: 1.3, look: .launch),
            Option(name: "F", theme: .impact, reveal: .box, accent: .yellow, size: 1.1, look: .orbit),
        ]
        case .tutorial: [
            Option(name: "A", theme: .educational, reveal: .highlight, accent: .yellow),
            Option(name: "B", theme: .educational, reveal: .box, accent: .yellow),
            Option(name: "C", theme: .educational, reveal: .highlight, accent: .yellow, look: .label),
            Option(name: "D", theme: .educational, reveal: .box, accent: .yellow, look: .soft),
            Option(name: "E", theme: .cue, reveal: .highlight, accent: .yellow, size: 1.1),
            Option(name: "F", theme: .educational, reveal: .highlight, accent: .yellow, size: 1.1, look: .signal),
        ]
        case .story: [
            Option(name: "A", theme: .editorial, reveal: .fade, size: 1.1, look: .editorial),
            Option(name: "B", theme: .editorial, reveal: .fade, size: 1.2, look: .logbook),
            Option(name: "C", theme: .editorial, reveal: .fade, look: .paper),
            Option(name: "D", theme: .editorial, reveal: .fade, size: 1.1),
            Option(name: "E", theme: .editorial, reveal: .highlight, accent: .peach),
            Option(name: "F", theme: .editorial, reveal: .fade, size: 1.25, look: .postcard),
        ]
        case .clean: [
            Option(name: "A", theme: .clean, reveal: .line, look: .minimal),
            Option(name: "B", theme: .clean, reveal: .line, look: .soft),
            Option(name: "C", theme: .interview, reveal: .line),
            Option(name: "D", theme: .clean, reveal: .line, look: .label),
            Option(name: "E", theme: .educational, reveal: .line),
            Option(name: "F", theme: .clean, reveal: .fade, size: 1.1),
        ]
        case .interview: [
            Option(name: "A", theme: .interview, reveal: .line, look: .soft),
            Option(name: "B", theme: .educational, reveal: .line),
            Option(name: "C", theme: .interview, reveal: .highlight, accent: .yellow),
            Option(name: "D", theme: .interview, reveal: .fade, size: 1.1),
            Option(name: "E", theme: .interview, reveal: .line, look: .label),
            Option(name: "F", theme: .educational, reveal: .fade, size: 1.05, look: .minimal),
        ]
        }
        return [current] + proposed
    }

    // MARK: - Drawing

    private var cue: CaptionCue {
        CaptionCue(words: Self.words.enumerated().map { index, word in
            CaptionWord(text: word, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4)
        })
    }

    /// The caption on screen at `time`, drawn as the compositor's cache draws it, and where it sits (top-left origin).
    private func caption(_ option: Option, at time: TimeInterval) throws -> (image: UIImage, rect: CGRect) {
        let states = CaptionCollectionRenderer.overlays([cue], settings: option.settings, position: .bottom, frame: frame, animation: option.reveal)
        let state = try #require(states.first { $0.span?.contains(time) == true })
        let lazy = try #require(state.lazyText)
        let settings = try #require(lazy.collection)
        let image = try #require(CaptionCollectionRenderer.image(lazy.text.text, settings: settings, frame: frame, emphasis: lazy.emphasis))
        let rect = CGRect(x: state.origin.x, y: frame.height - state.origin.y - state.size.height, width: state.size.width, height: state.size.height)
        return (image, rect)
    }

    private func frameImage(_ caption: (image: UIImage, rect: CGRect), picture: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: frame, format: format).image { _ in
            picture.draw(in: CGRect(origin: .zero, size: frame))
            caption.image.draw(in: caption.rect)
        }
    }

    /// A bright, busy daylight scene (the hardest place for white words) or a night one, each with a person in the middle.
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

    // MARK: - Strips

    private struct Cell {
        let frame: UIImage
        let caption: CGRect
    }

    /// Columns are the options, rows light and dark, each with the two moments.
    private func strip(_ options: [Option], cells: [[Cell]], rows: [String], crop: CGRect?, scale: CGFloat) -> UIImage {
        let source = crop ?? CGRect(origin: .zero, size: frame)
        let tile = CGSize(width: (source.width * scale).rounded(), height: (source.height * scale).rounded())
        let gutter: CGFloat = 170, header: CGFloat = 96, gap: CGFloat = 8
        let size = CGSize(
            width: gutter + CGFloat(options.count) * (tile.width + gap),
            height: header + CGFloat(rows.count) * (tile.height + gap)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let title: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: UIColor.white]
            let detail: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: UIColor(white: 0.85, alpha: 1)
            ]
            for (column, option) in options.enumerated() {
                let x = gutter + CGFloat(column) * (tile.width + gap)
                (option.name as NSString).draw(at: CGPoint(x: x + 6, y: 10), withAttributes: title)
                (option.detail as NSString).draw(in: CGRect(x: x + 6, y: 50, width: tile.width - 12, height: 44), withAttributes: detail)
                for (row, cell) in cells[column].enumerated() {
                    let y = header + CGFloat(row) * (tile.height + gap)
                    let target = CGRect(origin: CGPoint(x: x, y: y), size: tile)
                    guard let cropped = cell.frame.cgImage?.cropping(to: source) else { continue }
                    UIImage(cgImage: cropped).draw(in: target)
                }
            }
            for (row, label) in rows.enumerated() {
                let y = header + CGFloat(row) * (tile.height + gap)
                (label as NSString).draw(in: CGRect(x: 10, y: y + 10, width: gutter - 20, height: 80), withAttributes: detail)
            }
        }
    }

    @Test(arguments: VideoTemplate.allCases)
    func drawTheOptions(_ template: VideoTemplate) throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_CAPTION_OPTIONS"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let options = Self.options(for: template)
        let pictures = [(name: "light", image: picture(light: true)), (name: "dark", image: picture(light: false))]
        var rows: [String] = []
        for picture in pictures {
            for moment in Self.moments { rows.append("\(picture.name)\n\(moment.name)") }
        }
        let cells: [[Cell]] = try options.map { option in
            try pictures.flatMap { picture in
                try Self.moments.map { moment in
                    let drawn = try caption(option, at: moment.time)
                    return Cell(frame: frameImage(drawn, picture: picture.image), caption: drawn.rect)
                }
            }
        }
        let union = cells.flatMap { $0 }.map(\.caption).reduce(CGRect.null) { $0.union($1) }
        let crop = CGRect(x: 0, y: max(0, union.minY - 70), width: frame.width, height: min(frame.height, union.height + 140)).integral
        let whole = strip(options, cells: cells, rows: rows, crop: nil, scale: 0.4)
        try #require(whole.pngData()).write(to: folder.appending(path: "\(template.rawValue).png"))
        let detail = strip(options, cells: cells, rows: rows, crop: crop, scale: 0.6)
        try #require(detail.pngData()).write(to: folder.appending(path: "\(template.rawValue)-detail.png"))
    }
}
