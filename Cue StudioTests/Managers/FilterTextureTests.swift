//
//  FilterTextureTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// What the newer filters add beyond color: grain that is new every grain frame and the same for the same moment, a still's
/// fixed grain, the picture's size kept, and nothing for a color-only filter.
@Suite("Filter texture")
struct FilterTextureTests {
    private let gray = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 96, height: 96))

    @Test func theTexturedFiltersAreTheNewLooksAndTheRestAreColorAlone() {
        let textured = VideoFilter.collection.filter { FilterTexture.texture(for: $0) != nil }
        #expect(Set(textured) == [.warmFilm, .goldenGlow, .digicam, .vhs, .filmMono])
    }

    @Test func grainChangesFromFrameToFrameAndRepeatsForTheSameMoment() throws {
        let texture = try #require(FilterTexture.texture(for: .filmMono))
        let first = RenderedPixels(texture.apply(to: gray, time: 1))
        let again = RenderedPixels(texture.apply(to: gray, time: 1))
        let next = RenderedPixels(texture.apply(to: gray, time: 1 + 1 / FilterTexture.grainRate))
        let area = CGRect(x: 8, y: 8, width: 64, height: 64)
        #expect(first.luma(in: area) == again.luma(in: area))
        #expect(first.luma(in: area) != next.luma(in: area))
        // Grain, not a shift: around the gray it was.
        let values = first.luma(in: area)
        let mean = values.reduce(0, +) / Double(values.count)
        #expect(abs(mean - 128) < 12)
        #expect((values.max() ?? 0) - (values.min() ?? 0) > 10)
    }

    @Test func aTextureKeepsThePicturesSize() {
        for filter in VideoFilter.collection {
            guard let texture = FilterTexture.texture(for: filter) else { continue }
            #expect(texture.apply(to: gray, time: nil).extent == gray.extent, "\(filter)")
        }
    }

    @Test func noTextureIsNoChange() {
        let corner = CGRect(x: 8, y: 8, width: 8, height: 8)
        #expect(RenderedPixels(FilterTexture().apply(to: gray, time: 3)).luma(in: corner) == RenderedPixels(gray).luma(in: corner))
    }
}
