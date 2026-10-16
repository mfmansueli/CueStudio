//
//  PluralStringsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's counts vary by plural in the String Catalog (no more "1 lines"): each language picks its own form for the
/// number (one and other; Arabic's six; one form in Japanese, Chinese, Korean, Thai, Vietnamese and Indonesian), the number
/// is always written, and a second value (%@) after the count still lands in its place.
@Suite("Plural strings")
struct PluralStringsTests {
    /// The languages whose 1 and 2 take different words.
    private static let oneAndOther: [CueLanguage] = [
        .english, .spanish, .portugueseBrazil, .french, .german, .italian, .hindi, .dutch, .swedish, .danish, .norwegian, .arabic,
    ]

    /// Every count the editor shows, for `n` (the interpolations look up the plural keys).
    private static func counts(_ n: Int, in language: CueLanguage) -> [String] {
        [
            String(localized: "\(n) lines deleted", writtenIn: language),
            String(localized: "\(n) lines to check", writtenIn: language),
            String(localized: "\(n) lines", writtenIn: language),
            String(localized: "\(n) lines · tap one to jump there", writtenIn: language),
            String(localized: "\(n) lines changed in the original since they were translated.", writtenIn: language),
            String(localized: "\(n) lines follow the voice approximately.", writtenIn: language),
            String(localized: "\(n) keyframes", writtenIn: language),
            String(localized: "\(n) short pauses kept", writtenIn: language),
            String(localized: "Found \(n) pauses", writtenIn: language),
            String(localized: "Remove \(n) pauses", writtenIn: language),
            String(localized: "Frame frozen for \(n) seconds · drag its end to hold longer", writtenIn: language),
            String(localized: "Applies to all \(n) lines", writtenIn: language),
            String(localized: "All \(n) texts change together", writtenIn: language),
            String(localized: "\(n) matches", writtenIn: language),
            String(localized: "Replaced \(n) times", writtenIn: language),
            String(localized: "\(n) selected", writtenIn: language),
            String(localized: "Cut \(n) words from the video", writtenIn: language),
        ]
    }

    @Test func englishSaysOneLineAndTwoLines() {
        #expect(String(localized: "\(1) lines deleted", writtenIn: .english) == "1 line deleted")
        #expect(String(localized: "\(2) lines deleted", writtenIn: .english) == "2 lines deleted")
        #expect(String(localized: "Cut \(1) words from the video", writtenIn: .english) == "Cut 1 word from the video")
        #expect(String(localized: "\(1) matches", writtenIn: .english) == "1 match")
        #expect(String(localized: "Frame frozen for \(1) seconds · drag its end to hold longer", writtenIn: .english)
            == "Frame frozen for 1 second · drag its end to hold longer")
    }

    @Test func theCountAndTheValueAfterItEachLandInTheirPlace() {
        #expect(String(localized: "Removed \(1) pauses · \("0.4")", writtenIn: .english) == "Removed 1 pause · 0.4")
        #expect(String(localized: "Removed \(3) pauses · \("1.2")s", writtenIn: .english) == "Removed 3 pauses · 1.2s")
        #expect(String(localized: "\(1) words cut · \("0.8 s")", writtenIn: .english) == "1 word cut · 0.8 s")
        #expect(String(localized: "Removed \(1) pauses · \("0.4")", writtenIn: .portugueseBrazil) == "1 pausa removida · 0.4")
        #expect(String(localized: "\(2) words cut · \("0.8 s")", writtenIn: .portugueseBrazil) == "2 palavras cortadas · 0.8 s")
    }

    @Test(arguments: CueLanguage.allCases)
    func everyCountIsWrittenAndTranslated(language: CueLanguage) {
        for n in [0, 1, 2, 3, 11, 100] {
            for text in Self.counts(n, in: language) {
                #expect(text.contains(n.formatted(.number.grouping(.never).locale(Locale(identifier: "en_US_POSIX"))))
                    || text.contains(n.formatted()), "\(language) \(n): \(text)")
                #expect(!text.contains("%"), "\(language) left a placeholder: \(text)")
            }
        }
        if language != .english {
            #expect(Self.counts(2, in: language) != Self.counts(2, in: .english), "\(language) reads as English")
        }
    }

    @Test(arguments: oneAndOther)
    func oneAndTwoTakeTheirOwnWords(language: CueLanguage) {
        let one = String(localized: "\(1) lines deleted", writtenIn: language).replacingOccurrences(of: "1", with: "#")
        let two = String(localized: "\(2) lines deleted", writtenIn: language).replacingOccurrences(of: "2", with: "#")
        // German, Danish, Norwegian, Swedish, Dutch: "Zeile"/"Zeilen"; Arabic keeps its singular for 1 and 2 with digits, and
        // its plural from 3.
        if language == .arabic {
            let three = String(localized: "\(3) lines deleted", writtenIn: language).replacingOccurrences(of: "3", with: "#")
            #expect(one != three, "Arabic: 1 and 3 read the same")
        } else {
            #expect(one != two, "\(language): 1 and 2 read the same (\(one))")
        }
    }

    @Test func arabicHasItsFewAndManyForms() {
        let few = String(localized: "\(3) lines deleted", writtenIn: .arabic)
        let many = String(localized: "\(11) lines deleted", writtenIn: .arabic)
        #expect(few.contains("أسطر"))
        #expect(many.contains("سطرًا"))
    }
}
