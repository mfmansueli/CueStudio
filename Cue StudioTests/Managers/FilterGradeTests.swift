//
//  FilterGradeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The collection's grades, as math: each filter has its own look, keeps skin tones and detail,
/// and is sampled into a color cube that agrees with the grade.
@Suite("Filter grades")
struct FilterGradeTests {
    typealias Color = FilterGrade.Color

    /// From fair to deep, and one in shadow.
    private let skin: [Color] = [
        Color(0.96, 0.80, 0.69), Color(0.89, 0.69, 0.58), Color(0.78, 0.57, 0.43), Color(0.65, 0.45, 0.32),
        Color(0.48, 0.32, 0.22), Color(0.30, 0.20, 0.14), Color(0.35, 0.23, 0.17), Color(0.85, 0.62, 0.50),
    ]
    private let colors: [Color] = [
        Color(0.12, 0.12, 0.12), Color(0.5, 0.5, 0.5), Color(0.85, 0.85, 0.85), Color(0.35, 0.55, 0.85),
        Color(0.25, 0.5, 0.2), Color(0.8, 0.2, 0.2), Color(0.78, 0.57, 0.43),
    ]

    private func grade(_ filter: VideoFilter) throws -> FilterGrade {
        try #require(FilterGrade.grade(for: filter))
    }

    // MARK: - The collection

    @Test func theCollectionIsEightGradesAndTheFirstFiltersHaveNone() {
        #expect(VideoFilter.collection.count == 8)
        #expect(VideoFilter.collection.allSatisfy { FilterGrade.grade(for: $0) != nil })
        for legacy in VideoFilter.allCases where legacy.isLegacy || legacy == .original {
            #expect(FilterGrade.grade(for: legacy) == nil)
        }
        #expect(VideoFilter.editorFilters == [.original] + VideoFilter.collection)
        #expect(VideoFilter.collection.allSatisfy { !$0.isLegacy })
    }

    @Test func savedIdentifiersStayTheSame() throws {
        for (raw, filter) in [("vivid", VideoFilter.vivid), ("warm", .warm), ("cool", .cool), ("mono", .mono), ("film", .film), ("fade", .fade)] {
            #expect(filter.rawValue == raw)
            #expect(try JSONDecoder().decode(VideoFilter.self, from: Data("\"\(raw)\"".utf8)) == filter)
            #expect(filter.isLegacy && filter.defaultAmount == 1)
        }
        #expect(VideoFilter.warmEditorial.rawValue == "warmEditorial" && VideoFilter.monoContrast.rawValue == "monoContrast")
    }

    @Test func everyFilterStartsAtABalancedIntensity() {
        for filter in VideoFilter.collection {
            #expect((0.7...1).contains(filter.defaultAmount))
        }
        // The stronger the look, the further it starts from full.
        #expect(VideoFilter.cinema.defaultAmount < VideoFilter.studio.defaultAmount)
    }

    // MARK: - Skin and detail

    @Test func skinKeepsItsHueAndItsColorInTheFilmsThatShouldNotTurnIt() throws {
        for filter in [VideoFilter.natural, .studio, .soft, .cinema, .warmEditorial] {
            let grade = try grade(filter)
            for color in skin {
                let graded = grade.apply(to: color)
                let before = FilterGrade.hsv(color)
                let after = FilterGrade.hsv(graded)
                #expect(abs(after.hue - before.hue) < 3, "\(filter) hue")
                #expect((0.75...1.25).contains(after.saturation / before.saturation), "\(filter) saturation")
            }
        }
    }

    @Test func skinIsNeverMadeOrangerByTheBoostsOrTheTints() throws {
        // Studio and Natural raise color elsewhere, and Cinema tints shadows and highlights:
        // not skin.
        for filter in [VideoFilter.natural, .studio, .cinema] {
            let grade = try grade(filter)
            for color in skin {
                let graded = grade.apply(to: color)
                #expect(graded.x - graded.z <= color.x - color.z + 0.06, "\(filter)")
            }
        }
        #expect(FilterGrade.skinWeight(Color(0.78, 0.57, 0.43)) > 0.9)
        #expect(FilterGrade.skinWeight(Color(0.35, 0.55, 0.85)) == 0)
        #expect(FilterGrade.skinWeight(Color(0.25, 0.5, 0.2)) == 0)
    }

    @Test func noFilterFlattensTheToneOrInvertsIt() throws {
        for filter in VideoFilter.collection {
            let grade = try grade(filter)
            var previous = -1.0
            for step in 0...100 {
                let value = Double(step) / 100
                let luma = FilterGrade.luma(grade.apply(to: Color(repeating: value)))
                #expect(luma >= previous - 0.000_001, "\(filter) goes backwards at \(step)")
                if step > 0 { #expect((luma - previous) * 100 >= 0.45, "\(filter) flattens at \(step)") }
                previous = luma
            }
        }
    }

    @Test func blacksAndWhitesStayWhereAFilterPutsThem() throws {
        for filter in VideoFilter.collection {
            let grade = try grade(filter)
            #expect(FilterGrade.luma(grade.apply(to: Color(0, 0, 0))) <= 0.1, "\(filter) black")
            #expect(FilterGrade.luma(grade.apply(to: Color(1, 1, 1))) >= 0.9, "\(filter) white")
        }
        // Matte looks lift the black; Mono Contrast and Natural keep it.
        #expect(FilterGrade.luma(try grade(.retro).apply(to: Color(0, 0, 0))) > 0.05)
        #expect(FilterGrade.luma(try grade(.monoContrast).apply(to: Color(0, 0, 0))) == 0)
        #expect(FilterGrade.luma(try grade(.natural).apply(to: Color(0, 0, 0))) < 0.001)
    }

    // MARK: - Intent

    @Test func theMonoFiltersHaveNoColorLeft() throws {
        for filter in [VideoFilter.monoSoft, .monoContrast] {
            let grade = try grade(filter)
            for color in colors {
                let graded = grade.apply(to: color)
                #expect(max(graded.x, graded.y, graded.z) - min(graded.x, graded.y, graded.z) < 0.04, "\(filter)")
            }
        }
        // Contrast is darker in the shadows and brighter in the highlights than Soft.
        let soft = try grade(.monoSoft)
        let contrast = try grade(.monoContrast)
        #expect(contrast.apply(to: Color(repeating: 0.2)).x < soft.apply(to: Color(repeating: 0.2)).x)
        #expect(contrast.apply(to: Color(repeating: 0.8)).x > soft.apply(to: Color(repeating: 0.8)).x)
    }

    @Test func cinemaTintsTheShadowsTealAndTheHighlightsWarm() throws {
        let grade = try grade(.cinema)
        let shadow = grade.apply(to: Color(repeating: 0.12))
        #expect(shadow.y > shadow.x && shadow.z > shadow.x)
        let light = grade.apply(to: Color(repeating: 0.85))
        #expect(light.x > light.z)
    }

    @Test func warmEditorialIsWarmerThanNaturalAndSoftIsGentlerThanStudio() throws {
        let gray = Color(repeating: 0.5)
        let warm = try grade(.warmEditorial).apply(to: gray)
        let natural = try grade(.natural).apply(to: gray)
        #expect(warm.x - warm.z > natural.x - natural.z + 0.03)
        // Contrast through the middle tones: Studio's range is wider than Soft's.
        func spread(_ filter: VideoFilter) throws -> Double {
            let grade = try grade(filter)
            return grade.apply(to: Color(repeating: 0.75)).x - grade.apply(to: Color(repeating: 0.25)).x
        }
        #expect(try spread(.studio) > spread(.soft) + 0.1)
        // Retro fades: its whites sit lower than Natural's.
        #expect(FilterGrade.luma(try grade(.retro).apply(to: Color(repeating: 1))) < 0.95)
    }

    @Test func everyFilterLooksDifferentFromTheOthers() throws {
        let filters = VideoFilter.collection
        for (index, first) in filters.enumerated() {
            for second in filters[(index + 1)...] {
                let one = try grade(first)
                let two = try grade(second)
                let distance = colors.reduce(0.0) { total, color in
                    let a = one.apply(to: color)
                    let b = two.apply(to: color)
                    return total + abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)
                }
                #expect(distance > 0.25, "\(first) and \(second) are too alike")
            }
        }
    }

    @Test func saturatingNeverLeavesTheRange() throws {
        for filter in VideoFilter.collection {
            let grade = try grade(filter)
            for red in stride(from: 0.0, through: 1.0, by: 0.25) {
                for green in stride(from: 0.0, through: 1.0, by: 0.25) {
                    for blue in stride(from: 0.0, through: 1.0, by: 0.25) {
                        let graded = grade.apply(to: Color(red, green, blue))
                        #expect(graded.x >= 0 && graded.x <= 1 && graded.y >= 0 && graded.y <= 1 && graded.z >= 0 && graded.z <= 1)
                    }
                }
            }
        }
    }

    // MARK: - The cube

    @Test func theCubeAgreesWithTheGradeAtItsCorners() throws {
        let grade = try grade(.cinema)
        let dimension = 8
        let data = FilterLUT.make(grade, dimension: dimension)
        #expect(data.count == dimension * dimension * dimension * 4 * MemoryLayout<Float>.size)
        let floats = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        func cell(_ red: Int, _ green: Int, _ blue: Int) -> [Float] {
            let start = ((blue * dimension + green) * dimension + red) * 4
            return Array(floats[start..<start + 4])
        }
        for (red, green, blue) in [(0, 0, 0), (7, 0, 0), (0, 7, 0), (0, 0, 7), (7, 7, 7), (3, 5, 2)] {
            let expected = grade.apply(to: Color(Double(red) / 7, Double(green) / 7, Double(blue) / 7))
            let found = cell(red, green, blue)
            #expect(abs(Double(found[0]) - expected.x) < 0.000_01 && abs(Double(found[1]) - expected.y) < 0.000_01)
            #expect(abs(Double(found[2]) - expected.z) < 0.000_01 && found[3] == 1)
        }
    }

    @Test func theCubeIsMadeOnceAndKept() throws {
        let grade = try grade(.retro)
        let first = FilterLUT.cube(for: grade, key: "test.retro")
        let second = FilterLUT.cube(for: grade, key: "test.retro")
        #expect(first == second)
        #expect(first.count == FilterLUT.dimension * FilterLUT.dimension * FilterLUT.dimension * 16)
    }
}
