//
//  SampleEdit.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// The v10 design's demo edit, for UI tests (`-uiTestDemoEdit`): a 21.6 s take with eight caption
/// lines (one with "caudo", one with "não, pera"), a title and a subtitle, and the four pauses
/// between the lines already found by Clean Up.
enum SampleEdit {
    static let duration: TimeInterval = 21.6

    /// The design's lines: start, end and what is said.
    static let lines: [(TimeInterval, TimeInterval, String)] = [
        (0.3, 2.3, "Comidas de SP que todo mundo acha"),
        (2.3, 4.0, "que são só pra turista."),
        (5.2, 7.1, "Mas valem cada centavo."),
        (7.1, 9.0, "Primeiro: o pastel do… não, pera."),
        (10.1, 12.4, "Primeiro: o pastel de feira."),
        (12.4, 14.6, "Massa fina, muito recheio"),
        (14.6, 16.2, "e caudo de cana do lado."),
        (17.8, 20.6, "Segue pra ver os outros quatro."),
    ]

    static func make(aspect: AspectRatio) -> TakeEdit {
        var edit = TakeEdit(sourceDuration: duration, aspect: aspect)
        edit.captions = lines.map { CaptionCue(text: $0.2, start: $0.0, end: $0.1) }
        edit.showsCaptions = true
        var title = TextOverlay(
            role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0.2, end: 3.8)
        )
        title.text = "5 comidas de SP"
        var subtitle = TextOverlay(
            role: .subtitle, look: TypePreset.minimal.look(for: .title), preset: .minimal, span: TimeSpan(start: 10.1, end: 12.4)
        )
        subtitle.text = "Pastel de feira"
        edit.texts = [title, subtitle]
        edit.suggestions = pauses.map { CleanUpSuggestion(kind: .pause, span: $0, confidence: 0.9) }
        edit.cleanUpAnalyzed = true
        return edit
    }

    /// The silences between the lines, each cut keeping a breath on both sides (none at the end).
    private static var pauses: [TimeSpan] {
        let padding = SilenceDetector.padding
        return [
            TimeSpan(start: 4.0 + padding, end: 5.2 - padding),
            TimeSpan(start: 9.0 + padding, end: 10.1 - padding),
            TimeSpan(start: 16.2 + padding, end: 17.8 - padding),
            TimeSpan(start: 20.6 + padding, end: duration),
        ]
    }
}
#endif
