//
//  CoverCompositionTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Cover Studio's compositions: templates as starting points that keep the creator's work when switched, a saved style that
/// never carries another cover's words or picture, framing that always covers the frame, and covers made before it.
@Suite("Cover composition")
struct CoverCompositionTests {
    @Test func everyTemplateStartsReadable() {
        for template in CoverTemplate.allCases {
            let composition = CoverComposition.make(template, title: "3 morning habits that changed my life", handle: "maya", episode: 4)
            #expect(composition.template == template)
            #expect(composition.title.background != .none, "\(template) keeps its words readable")
            #expect(CoverTitleStyle.sizeRange.contains(composition.title.size))
        }
        #expect(CoverComposition.make(.beforeAfter, title: "x").split != nil)
        #expect(CoverComposition.make(.series, title: "x", episode: 4).title.kicker == "EP 04")
        #expect(CoverComposition.make(.series, title: "x", handle: "maya").items.first?.text == "maya")
        #expect(CoverComposition.make(.list, title: "5 foods").title.showsNumber)
    }

    @Test func switchingTemplatesKeepsWhatTheCreatorMade() {
        var composition = CoverComposition.make(.educational, title: "Morning habits")
        composition.framing = CoverFraming(zoom: 2, offsetX: 0.3, offsetY: 0)
        composition.title.highlights = [0]
        composition.items.append(CoverItem(kind: .tag, center: .center, text: "NEW"))
        let demo = composition.applying(.demo, title: "Morning habits")
        #expect(demo.template == .demo)
        #expect(demo.framing == composition.framing)
        #expect(demo.title.highlights == [0])
        // The demo's own circle and arrow, and the creator's tag.
        #expect(demo.items.map(\.kind) == [.circle, .arrow, .tag])
        // Back: the demo's untouched circle and arrow go, the tag stays.
        let back = demo.applying(.opinion, title: "Morning habits")
        #expect(back.items.map(\.kind) == [.tag])
    }

    @Test func myStyleKeepsTheLookNotTheWordsOrThePicture() {
        var composition = CoverComposition.make(.series, title: "Episode about coffee", handle: "maya", episode: 7)
        composition.title.accent = .cyan
        composition.title.highlights = [2]
        composition.framing = CoverFraming(zoom: 3)
        composition.items.append(CoverItem(kind: .tag, center: .center, text: "LIMITED"))
        composition.effect = .dim
        let style = composition.style
        #expect(style.title.highlights.isEmpty)
        #expect(style.title.kicker.isEmpty)
        #expect(style.items.first { $0.kind == .tag }?.text.isEmpty == true)
        let next = style.composition(title: "Tea time", handle: "maya", episode: 8)
        #expect(next.title.accent == .cyan)
        #expect(next.effect == .dim)
        #expect(next.framing == CoverFraming())
        #expect(next.title.kicker == "EP 08")
        #expect(next.items.contains { $0.kind == .tag && $0.text == "NEW" })
        #expect(next.items.contains { $0.kind == .handle && $0.text == "maya" })
    }

    @Test func framingAlwaysCoversTheFrame() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        let picture = CGSize(width: 400, height: 300)
        for framing in [CoverFraming(), CoverFraming(zoom: 0.5, offsetX: -3, offsetY: 3), CoverFraming(zoom: 3, offsetX: 1, offsetY: -1)] {
            let rect = framing.rect(for: picture, in: frame)
            #expect(rect.minX <= frame.minX + 0.001 && rect.maxX >= frame.maxX - 0.001)
            #expect(rect.minY <= frame.minY + 0.001 && rect.maxY >= frame.maxY - 0.001)
        }
        // Dragging right shows more of the left side.
        let moved = CoverFraming().moved(by: CGSize(width: 30, height: 0), picture: picture, frame: frame.size)
        #expect(moved.offsetX < 0)
        #expect(CoverFraming().zoomed(by: 10).zoom == CoverFraming.zoomRange.upperBound)
    }

    @Test func coversMadeBeforeCoverStudioOpenAsTheNearestTemplate() {
        var cover = VideoCover(source: .frame(2))
        cover.title = "5 comidas de SP"
        var design = CoverDesign()
        design.layout = .number
        design.effect = .blur
        design.elements = [.badge, .arrow]
        cover.design = design
        let composition = CoverComposition(legacy: cover)
        #expect(composition.template == .list)
        #expect(composition.effect == .blur)
        #expect(Set(composition.items.map(\.kind)) == [.tag, .arrow])
        #expect(composition.items.contains { $0.text == "NEW" })
        // A plain title from before the design keeps its place.
        var plain = VideoCover(source: .frame(1))
        plain.title = "Hi"
        plain.titleY = 0.7
        #expect(CoverComposition(legacy: plain).title.center.y == 0.7)
    }

    @Test func aCompositionSurvivesSavingAndOpening() throws {
        var cover = VideoCover(source: .frame(1))
        cover.composition = CoverComposition.make(.beforeAfter, title: "Glow up")
        cover.composition?.split?.source = .photo(fileName: "after.jpg")
        cover.composition?.items = [CoverItem(kind: .arrow, center: .center, rotation: 0.4)]
        let decoded = try JSONDecoder().decode(VideoCover.self, from: JSONEncoder().encode(cover))
        #expect(decoded == cover)
    }
}
