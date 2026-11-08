//
//  ReadTime.swift
//  Cue Studio
//

import Foundation
import Synchronization

/// Reading-time estimates for scripts. Cue markers like `[pause]` are not spoken, so they don't count.
nonisolated enum ReadTime {
    /// Pace at 1.0× prompter speed. Calibrated so the default speed (`naturalSpeed`) lands on a
    /// natural on-camera pace of about 150 words a minute. Scrolling and every estimate in the app
    /// use this one constant.
    static let wordsPerMinuteAtOneX: Double = 215

    /// Default prompter speed: 150 words a minute (0.698 on the stored scale), shown as 1× (`SpeedScale`).
    static let naturalSpeed: Double = 150 / wordsPerMinuteAtOneX

    /// Words separated by spaces. Scripts in languages written without spaces (Japanese, Chinese,
    /// Thai) count dictionary words instead, which read at about the same pace.
    static func wordCount(in text: String) -> Int {
        if let known = counted.withLock({ $0[text] }) { return known }
        let count = countWords(in: text)
        counted.withLock { counted in
            if counted.count >= countedLimit { counted.removeAll() }
            counted[text] = count
        }
        return count
    }

    /// Each text's count, kept: the Scripts list asks every row for its reading time each time it is drawn, and the Studio for the
    /// script's, while the words stay the same (`countedLimit` texts, then it starts again).
    private static let counted = Mutex<[String: Int]>([:])
    static let countedLimit = 256

    private static func countWords(in text: String) -> Int {
        let spoken = CueParser.stripCues(text)
        if WordSegmenter.containsUnspacedScript(spoken) {
            return WordSegmenter.wordCount(in: spoken)
        }
        // Only what is said counts: a cue before a full stop ("básicos [sorpresa].") leaves the stop alone, and a dash or an ellipsis between
        // spaces is no word. Counted as words, they made Apple Intelligence's scripts (a cue before most stops) seem 4 to 6% longer than they
        // are read (ScriptToolsQualityDeviceTests, 01/11/2026), and "Fit to time" stopped short of the range.
        return spoken
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }

    /// How many words a minute `language` is spoken at, as a share of English's: the same minute holds fewer words in Korean (whose words carry
    /// their particles) and more in French. Measured two ways (01/11/2026, `tools/pace/measure.py`, `research_notes/Pace/pace.json`): the words a
    /// second of people reading aloud (FLEURS, four people a language, silences trimmed) and the words each language needs to say what English
    /// says (the app's translated sentences of eight words or more). The pace is their geometric mean, brought a quarter of the way back to 1 for
    /// the four readings' noise, to the nearest 0.05; 1 when it is within 7% of 1 or when the two point opposite ways (Japanese, Swedish, Thai,
    /// Portuguese). Nil (unknown) is English's.
    static func pace(for language: CueLanguage?) -> Double {
        switch language {
        case .korean: 0.75
        case .turkish: 0.8
        case .indonesian: 0.85
        case .arabic: 0.9
        case .spanish, .hindi, .norwegian, .dutch, .chineseSimplified, .chineseTraditional: 1.1
        case .french, .vietnamese: 1.15
        default: 1
        }
    }

    /// Words read aloud per minute at a prompter speed, in `language` (nil: English's pace).
    static func wordsPerMinute(speed: Double, language: CueLanguage? = nil) -> Double {
        wordsPerMinuteAtOneX * max(speed, 0.1) * pace(for: language)
    }

    /// Seconds needed to read `text` aloud at the given prompter speed, in `language` (nil: English's pace).
    static func seconds(for text: String, speed: Double = naturalSpeed, language: CueLanguage? = nil) -> TimeInterval {
        Double(wordCount(in: text)) / (wordsPerMinute(speed: speed, language: language) / 60)
    }

    /// Roughly how many words fit in `seconds` at the given speed, in `language` (nil: English's pace). Used to brief the AI on length.
    static func words(for seconds: TimeInterval, speed: Double = naturalSpeed, language: CueLanguage? = nil) -> Int {
        Int((seconds * wordsPerMinute(speed: speed, language: language) / 60).rounded())
    }
}
