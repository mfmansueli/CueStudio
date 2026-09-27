//
//  TakeEditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("TakeEdit")
struct TakeEditTests {
    private func edit(_ duration: TimeInterval = 60) -> TakeEdit {
        TakeEdit(sourceDuration: duration, aspect: .portrait)
    }

    @Test func untouchedEditPlaysTheWholeTake() {
        let edit = edit()
        #expect(edit.keptSpans == [TimeSpan(start: 0, end: 60)])
        #expect(edit.editedDuration == 60)
        #expect(!edit.differs(from: .portrait))
    }

    @Test func trimShortensAndKeepsHandlesApart() {
        var edit = edit()
        edit.setTrim(start: 5)
        edit.setTrim(end: 50)
        #expect(edit.editedDuration == 45)
        edit.setTrim(start: 49.8)
        #expect(edit.trimStart == 49.5)
        #expect(edit.differs(from: .portrait))
    }

    @Test func splitAndDeleteRemoveASection() {
        var edit = edit()
        let result1 = edit.split(at: 20)
        #expect(result1)
        let result2 = edit.split(at: 30)
        #expect(result2)
        #expect(edit.segments.count == 3)
        let result3 = edit.removeSegment(containing: 25)
        #expect(result3)
        #expect(edit.keptSpans == [TimeSpan(start: 0, end: 20), TimeSpan(start: 30, end: 60)])
        #expect(edit.editedDuration == 50)
    }

    @Test func splitsTooCloseAreIgnored() {
        var edit = edit()
        let result4 = edit.split(at: 20)
        #expect(result4)
        let result5 = edit.split(at: 20.2)
        #expect(!result5)
        let result6 = edit.split(at: 0.1)
        #expect(!result6)
    }

    @Test func theLastSectionCannotBeDeleted() {
        var edit = edit()
        let result7 = edit.removeSegment(containing: 10)
        #expect(!result7)
        edit.split(at: 30)
        let result8 = edit.removeSegment(containing: 10)
        #expect(result8)
        let result9 = edit.removeSegment(containing: 40)
        #expect(!result9)
    }

    @Test func silencesAreCutOnlyWhenRemoved() {
        var edit = edit()
        edit.silences = [TimeSpan(start: 10, end: 13), TimeSpan(start: 40, end: 41)]
        #expect(edit.editedDuration == 60)
        edit.removesSilences = true
        #expect(edit.editedDuration == 56)
        #expect(edit.keptSpans.count == 3)
    }

    @Test func captionsFollowTheCuts() {
        var edit = edit()
        edit.captions = [
            CaptionCue(text: "Before", start: 5, end: 7),
            CaptionCue(text: "Cut", start: 22, end: 24),
            CaptionCue(text: "After", start: 35, end: 37),
        ]
        edit.split(at: 20)
        edit.split(at: 30)
        edit.removeSegment(containing: 25)
        let captions = edit.editedCaptions
        #expect(captions.map(\.text) == ["Before", "After"])
        #expect(captions.last?.start == 25)
    }

    @Test func editedTimeMapsAcrossRemovedSections() {
        var edit = edit()
        edit.split(at: 20)
        edit.split(at: 30)
        edit.removeSegment(containing: 25)
        #expect(edit.editedTime(forSource: 10) == 10)
        #expect(edit.editedTime(forSource: 25) == nil)
        #expect(edit.editedTime(forSource: 31) == 21)
    }

    @Test func subtractingAndMergingSpans() {
        let pieces = TakeEdit.subtract([TimeSpan(start: 2, end: 3), TimeSpan(start: 5, end: 12)], from: TimeSpan(start: 0, end: 10))
        #expect(pieces == [TimeSpan(start: 0, end: 2), TimeSpan(start: 3, end: 5)])
        #expect(TakeEdit.merged([TimeSpan(start: 3, end: 5), TimeSpan(start: 0, end: 3)]) == [TimeSpan(start: 0, end: 5)])
    }

    @Test func roundTrips() throws {
        var edit = edit()
        edit.split(at: 12)
        edit.filter = .film
        edit.showsCaptions = true
        edit.captions = [CaptionCue(text: "Hi", start: 0, end: 1)]
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(decoded == edit)
    }
}
