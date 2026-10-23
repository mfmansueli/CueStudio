//
//  CaptionMapTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The lines timed to the edit, worked out once: found by line and by moment exactly as mapping them every time would, with
/// a cut, a copied section showing a line again, and an hour of lines.
@Suite("Caption map")
struct CaptionMapTests {
    private static func lines(_ count: Int, every seconds: TimeInterval) -> [CaptionCue] {
        (0..<count).map { CaptionCue(text: "Line \($0)", start: Double($0) * seconds, end: Double($0) * seconds + seconds * 0.8) }
    }

    @Test func itAnswersLikeTheMappingItKeeps() throws {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.captions = Self.lines(10, every: 2)
        _ = edit.timeline.removeEdited(4...6)
        let copied = try #require(edit.timeline.segments.first?.id)
        _ = edit.timeline.duplicateSegment(id: copied)
        let map = CaptionMap(edit)
        let instances = edit.editedCaptionInstances
        #expect(map.instances.map(\.line) == instances.map(\.line))
        for instance in instances {
            #expect(map.cueID(forLine: instance.line.id) == instance.cueID)
            #expect(map.line(instance.line.id)?.span == instance.line.span)
        }
        for time in stride(from: 0.0, through: edit.editedDuration, by: 0.13) {
            let expected = instances.first { $0.line.start <= time && time < $0.line.end }
            #expect(map.instance(at: time)?.line.id == expected?.line.id, "at \(time)")
        }
        // A copy shows the line again under another identity, which leads back to it.
        #expect(instances.contains { $0.line.id != $0.cueID })
    }

    @Test func anHourOfLinesIsFoundQuickly() {
        var edit = TakeEdit(sourceDuration: 3600, aspect: .portrait)
        edit.captions = Self.lines(1200, every: 3)
        let map = CaptionMap(edit)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for second in 0..<3600 { _ = map.instance(at: Double(second) + 0.5) }
        }
        #expect(map.instance(at: 1800.5)?.line.text == "Line 600")
        #expect(elapsed < .milliseconds(50), "\(elapsed)")
    }
}
