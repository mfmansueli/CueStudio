//
//  CoverGalleryCaptureTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Every Cover Studio template drawn with short and long titles, in several languages, over a light and a dark picture, as
/// contact sheets to look at (opt-in: `TEST_RUNNER_CUE_COVER_GALLERY=<folder on the Mac>`). The pictures are drawn here: a
/// bright, busy daylight scene (the hardest place for white words) and a night one, each with a person-like shape.
@MainActor
@Suite("Cover gallery capture", .enabled(if: ProcessInfo.processInfo.environment["CUE_COVER_GALLERY"] != nil))
struct CoverGalleryCaptureTests {
    private let tile = CGSize(width: 360, height: 640)

    private static let titles: [(name: String, text: String)] = [
        ("short", "Real talk"),
        ("long", "Nobody tells you this about moving abroad alone at thirty and starting from zero"),
        ("list", "5 foods you must try in São Paulo this year"),
        ("pt", "Coração de São Paulo: o que ninguém conta"),
        ("ar", "ثلاث عادات صباحية غيرت حياتي"),
        ("ja", "朝の習慣を変えたら人生が変わった"),
        ("th", "วิธีทำกาแฟให้อร่อยที่บ้าน"),
        ("emoji", "Glow up in 30 days ✨🔥"),
    ]

    private func picture(light: Bool) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = light
                ? [UIColor(red: 0.98, green: 0.96, blue: 0.9, alpha: 1), UIColor(red: 0.85, green: 0.9, blue: 0.97, alpha: 1)]
                : [UIColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1), UIColor(red: 0.16, green: 0.1, blue: 0.2, alpha: 1)]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            // Busy detail: windows, plants, light spots.
            for index in 0..<60 {
                let x = CGFloat((index * 137) % 1080), y = CGFloat((index * 251) % 1920)
                (light ? UIColor(white: 1, alpha: 0.7) : UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.35)).setFill()
                UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 120, height: 60), cornerRadius: 12).fill()
            }
            // A person: head and shoulders in the middle.
            (light ? UIColor(red: 0.55, green: 0.38, blue: 0.3, alpha: 1) : UIColor(red: 0.42, green: 0.3, blue: 0.26, alpha: 1)).setFill()
            UIBezierPath(ovalIn: CGRect(x: 390, y: 620, width: 300, height: 380)).fill()
            UIColor(red: 0.2, green: 0.35, blue: 0.6, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 240, y: 980, width: 600, height: 1000), cornerRadius: 260).fill()
        }
    }

    @Test func drawEveryTemplate() throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_COVER_GALLERY"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for light in [true, false] {
            let main = picture(light: light)
            for (name, title) in Self.titles {
                let templates = CoverTemplate.allCases
                let sheet = CGSize(width: tile.width * CGFloat(templates.count), height: tile.height)
                let image = UIGraphicsImageRenderer(size: sheet).image { _ in
                    for (column, template) in templates.enumerated() {
                        let composition = CoverComposition.make(template, title: title, handle: "maya.cooks", episode: 3)
                        let cover = CoverCompositionRenderer.image(
                            title: title, composition: composition, pictures: .init(main: main, second: picture(light: !light)), size: tile, cutout: nil
                        )
                        cover.draw(in: CGRect(origin: CGPoint(x: tile.width * CGFloat(column), y: 0), size: tile))
                    }
                }
                let file = folder.appending(path: "cover-\(light ? "light" : "dark")-\(name).png")
                try #require(image.pngData()).write(to: file)
            }
        }
    }

    @Test func drawEveryTransition() throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["CUE_COVER_GALLERY"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let from = try #require(CIImage(image: picture(light: true))).transformed(by: CGAffineTransform(scaleX: 1.0 / 3, y: 1.0 / 3))
        let to = try #require(CIImage(image: picture(light: false))).transformed(by: CGAffineTransform(scaleX: 1.0 / 3, y: 1.0 / 3))
        let steps = [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0]
        let size = from.extent.size
        let context = CIContext()
        for transition in [EditTransition.zoom, .blur, .flash, .push, .punch, .wipe] {
            let sheet = CGSize(width: size.width * CGFloat(steps.count), height: size.height)
            let image = UIGraphicsImageRenderer(size: sheet).image { _ in
                for (column, step) in steps.enumerated() {
                    let frame = TransitionDrawing.draw(transition, from: from, to: to, progress: step)
                    if let cg = context.createCGImage(frame, from: from.extent) {
                        UIImage(cgImage: cg).draw(in: CGRect(origin: CGPoint(x: size.width * CGFloat(column), y: 0), size: size))
                    }
                }
            }
            try #require(image.pngData()).write(to: folder.appending(path: "transition-\(transition.rawValue).png"))
        }
    }
}
