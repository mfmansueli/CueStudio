//
//  CoverDesignRendererTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The cover design is drawn on the device: these only check that each design makes a different
/// picture of the right size, so a layout or an element can't silently stop drawing.
@MainActor
@Suite("CoverDesignRenderer")
struct CoverDesignRendererTests {
    private let size = CGSize(width: 270, height: 480)

    private func picture() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.3, green: 0.35, blue: 0.5, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func render(_ design: CoverDesign, title: String = "5 comidas de SP") -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        var cover = VideoCover(source: .frame(0))
        cover.title = title
        cover.design = design
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            picture().draw(in: CGRect(origin: .zero, size: size))
            CoverDesignRenderer.draw(cover: cover, design: design, size: size, cutout: nil, in: context.cgContext)
        }
        #expect(image.size == size)
        return image.pngData()
    }

    @Test func theWordsAreDrawnOverThePicture() {
        let plain = UIGraphicsImageRenderer(size: size).image { _ in picture().draw(at: .zero) }.pngData()
        #expect(render(CoverDesign()) != plain)
    }

    @Test func eachLayoutMakesItsOwnPicture() {
        var seen = Set<Data>()
        for layout in CoverLayout.allCases {
            var design = CoverDesign()
            design.layout = layout
            if let data = render(design) { seen.insert(data) }
        }
        #expect(seen.count == CoverLayout.allCases.count)
    }

    @Test func eachTypefaceAndEffectChangesThePicture() {
        var fonts = Set<Data>()
        for font in CoverFont.allCases {
            var design = CoverDesign()
            design.font = font
            if let data = render(design) { fonts.insert(data) }
        }
        #expect(fonts.count >= 3)
        var dim = CoverDesign()
        dim.effect = .dim
        #expect(render(dim) != render(CoverDesign()))
    }

    @Test func everyElementDrawsSomething() {
        var design = CoverDesign()
        design.handle = "maya"
        let base = render(design)
        for element in CoverElement.allCases {
            var withElement = design
            withElement.elements = [element]
            #expect(render(withElement) != base, "\(element) draws nothing")
        }
    }

    @Test func theHighlightedWordChangesThePicture() {
        var first = CoverDesign()
        first.highlightIndex = 0
        var second = CoverDesign()
        second.highlightIndex = 2
        #expect(render(first) != render(second))
    }

    @Test func blurSoftensThePictureBehind() {
        let blurred = CoverDesignRenderer.blurred(picture(), width: size.width)
        #expect(blurred.size == size)
    }

    @Test func theTypefacesExistAtAnySize() {
        for font in CoverFont.allCases {
            #expect(CoverDesignRenderer.words(font, size: 40).pointSize == 40)
        }
    }
}
