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

    @Test func timelineChangesCount() {
        var edit = edit()
        edit.timeline.trimStart(to: 5)
        #expect(edit.editedDuration == 55)
        #expect(edit.differs(from: .portrait))
    }

    @Test func pauseSuggestionsAloneChangeNothing() {
        var edit = edit()
        edit.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 10, end: 12), confidence: 1)]
        #expect(!edit.differs(from: .portrait))
    }

    @Test func captionsFollowTheCuts() {
        var edit = edit()
        edit.captions = [
            CaptionCue(text: "Before", start: 5, end: 7),
            CaptionCue(text: "Cut", start: 22, end: 24),
            CaptionCue(text: "After", start: 35, end: 37),
        ]
        edit.timeline.split(atEdited: 20)
        edit.timeline.split(atEdited: 30)
        edit.timeline.removeSegment(id: edit.timeline.segments[1].id)
        let captions = edit.editedCaptions
        #expect(captions.map(\.text) == ["Before", "After"])
        #expect(captions.last?.start == 25)
    }

    @Test func roundTrips() throws {
        var edit = edit()
        edit.timeline.split(atEdited: 12)
        edit.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 3, end: 4), confidence: 1)]
        edit.filter = .film
        edit.showsCaptions = true
        edit.captions = [CaptionCue(text: "Hi", start: 0, end: 1)]
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(decoded == edit)
    }

    // MARK: - Edits saved by earlier builds

    @Test func olderEditsOpenWithTheSamePieces() throws {
        let json = """
        {"sourceDuration": 60, "trimStart": 5, "trimEnd": 50, "splits": [20, 30],
         "removed": [{"start": 20, "end": 30}], "silences": [], "removesSilences": false,
         "volume": 1.2, "enhancesVoice": false, "reducesNoise": true, "exposure": 10, "contrast": 0,
         "warmth": 0, "filter": "mono", "aspect": "9:16", "cropOffset": 0, "showsCaptions": false,
         "captionStyle": "bold", "captionPosition": "bottom", "captions": []}
        """
        let edit = try JSONDecoder().decode(TakeEdit.self, from: Data(json.utf8))
        #expect(edit.keptSpans == [TimeSpan(start: 5, end: 20), TimeSpan(start: 30, end: 50)])
        #expect(edit.editedDuration == 35)
        #expect(edit.volume == 1.2)
        #expect(edit.filter == .mono)
        #expect(!edit.enhancesVoice)
    }

    @Test func olderSilencesBecomePauseSuggestions() throws {
        let json = """
        {"sourceDuration": 60, "trimStart": 0, "trimEnd": 60, "splits": [], "removed": [],
         "silences": [{"start": 10, "end": 13}, {"start": 40, "end": 41}], "removesSilences": true,
         "aspect": "9:16"}
        """
        let edit = try JSONDecoder().decode(TakeEdit.self, from: Data(json.utf8))
        #expect(edit.editedDuration == 56)
        #expect(edit.suggestions.map(\.kind) == [.pause, .pause])
        #expect(edit.suggestions.allSatisfy { edit.timeline.isRemoved($0.span) })
    }
}
