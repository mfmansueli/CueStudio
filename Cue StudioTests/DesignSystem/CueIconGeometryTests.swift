//
//  CueIconGeometryTests.swift
//  Cue StudioTests
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Cue_Studio

/// The icon set drawn in code: the SVG path reader, the shapes it makes and the stroke rule (about 1.6 pt at any size).
@Suite("CueIconGeometry")
struct CueIconGeometryTests {
    // MARK: - The path reader

    @Test func linesHorizontalsAndVerticalsMakeTheirBox() {
        let box = SVGPathParser.path(from: "M5 4H19V20h-14z").boundingRect
        #expect(box == CGRect(x: 5, y: 4, width: 14, height: 16))
    }

    @Test func compactNumbersAreSplitTheWayTheyAreWritten() {
        // "4.5.5" is 4.5 and .5; "-1.5" follows without a space.
        let box = SVGPathParser.path(from: "M4.5.5l-1.5 2").boundingRect
        #expect(abs(box.minX - 3) < 1e-9 && abs(box.maxX - 4.5) < 1e-9)
        #expect(abs(box.minY - 0.5) < 1e-9 && abs(box.maxY - 2.5) < 1e-9)
    }

    @Test func aCircleWrittenAsTwoArcsFillsItsSquare() {
        // The same circle the generator writes for `<circle cx="12" cy="12" r="8.5">`.
        let box = SVGPathParser.path(from: "M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0z").boundingRect
        #expect(abs(box.minX - 3.5) < 0.01 && abs(box.maxX - 20.5) < 0.01)
        #expect(abs(box.minY - 3.5) < 0.01 && abs(box.maxY - 20.5) < 0.01)
    }

    @Test func aRoundedCornerArcStaysInsideItsCorner() {
        // The top-left corner of a card: from (5, 6.5) to (6.5, 5), radius 1.5, sweeping clockwise.
        let corner = SVGPathParser.path(from: "M5 6.5A1.5 1.5 0 0 1 6.5 5").boundingRect
        #expect(abs(corner.minX - 5) < 0.01 && abs(corner.maxY - 6.5) < 0.01)
        #expect(corner.width <= 1.5 + 0.01 && corner.height <= 1.5 + 0.01)
    }

    @Test func aRotatedEllipseArcReachesItsEnd() {
        let path = SVGPathParser.path(from: "M20.59 8.18A9.4 4.2 -24 0 1 3.41 15.82")
        let end = path.currentPoint
        #expect(abs((end?.x ?? 0) - 3.41) < 1e-4 && abs((end?.y ?? 0) - 15.82) < 1e-4)
    }

    @Test func aSmoothCurveMirrorsTheLastControlPoint() {
        let smooth = SVGPathParser.path(from: "M0 0C0 4 4 4 4 0S8 -4 8 0").boundingRect
        #expect(abs(smooth.maxX - 8) < 1e-9)
        #expect(smooth.minY < -1, "the second hump goes up: the first control is mirrored")
    }

    @Test func dataThatRunsOutKeepsWhatWasRead() {
        let box = SVGPathParser.path(from: "M1 1L5 5L").boundingRect
        #expect(box == CGRect(x: 1, y: 1, width: 4, height: 4))
    }

    // MARK: - The set

    @Test func everyIconHasShapesInsideItsGrid() {
        let grid = CGRect(x: -0.5, y: -0.5, width: CueIconGeometry.grid + 1, height: CueIconGeometry.grid + 1)
        for icon in CueIcon.allCases {
            let elements = CueIconGeometry.elements(for: icon)
            #expect(!elements.isEmpty, "\(icon)")
            for element in elements {
                #expect(!element.path.isEmpty, "\(icon)")
                #expect(grid.contains(element.path.boundingRect), "\(icon) leaves the grid: \(element.path.boundingRect)")
                #expect(element.filled || element.stroked, "\(icon) draws nothing")
            }
        }
    }

    @Test func playIsSolidAndTakesHasASolidTriangle() {
        #expect(CueIconGeometry.elements(for: .play).allSatisfy { $0.filled && !$0.stroked })
        let takes = CueIconGeometry.elements(for: .takes)
        #expect(takes.count == 3 && takes[2].filled && takes[0].stroked && !takes[0].filled)
    }

    @Test func findInspirationsOrbitPassesBehindTheBulbAndAcrossIt() {
        let parts = CueIconGeometry.elements(for: .findInspiration)
        let glass = SVGPathParser.path(from: "M9 17v-1.6c0-1.2-.6-2.2-1.5-3.1A6.3 6.3 0 1 1 16.5 12.3c-.9.9-1.5 1.9-1.5 3.1V17z")
        let farSide = parts[0], nearSide = parts[3]
        #expect(parts.count == 4 && parts.allSatisfy { $0.stroked && !$0.filled })
        #expect(farSide.opacity < 1 && parts.dropFirst().allSatisfy { $0.opacity == 1 }, "only the far side of the orbit is softer")
        // The far side stops where the glass hides it (nothing of it inside the bulb); the near side crosses it.
        func points(along path: Path) -> [CGPoint] {
            stride(from: 0.04, through: 0.96, by: 0.04).compactMap { path.trimmedPath(from: 0, to: $0).currentPoint }
        }
        #expect(!points(along: farSide.path).contains { glass.contains($0) }, "the far side stays behind the glass")
        #expect(points(along: nearSide.path).contains { glass.contains($0) }, "the near side passes in front of the glass")
    }

    @Test func aMarkedBestTakeCanFillItsClosedShapes() {
        let best = CueIconGeometry.elements(for: .bestTake)
        #expect(best.contains { $0.closed && $0.stroked })
    }

    // MARK: - The stroke

    @Test func theStrokeIsAboutOnePointSixAtTheSizesTheAppUses() {
        for size in [16.0, 18, 20, 22] {
            let width = CueIconGeometry.strokeWidth(forSize: size)
            #expect(abs(width - 1.6) < 0.001, "size \(size): \(width)")
        }
    }

    @Test func theStrokeStaysWithinTheGridLimits() {
        // Big icons don't go hairline (1.7 grid units at least), tiny ones don't clot (3.4 at most).
        #expect(CueIconGeometry.strokeInGridUnits(forSize: 44) == 1.7)
        #expect(CueIconGeometry.strokeInGridUnits(forSize: 26) == 1.7)
        #expect(CueIconGeometry.strokeInGridUnits(forSize: 8) == 3.4)
        #expect(abs(CueIconGeometry.strokeWidth(forSize: 26) - 1.7 * 26 / 24) < 1e-9)
        #expect(CueIconGeometry.strokeInGridUnits(forSize: 0) == 1.7)
    }
}
