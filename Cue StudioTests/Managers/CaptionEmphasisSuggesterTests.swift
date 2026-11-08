//
//  CaptionEmphasisSuggesterTests.swift
//  Cue StudioTests
//

import Foundation
import NaturalLanguage
import Testing
@testable import Cue_Studio

/// Suggest emphasis's rule (owner, 08/11/2026), on lines a creator says and on captions heard from real people in Portuguese and
/// English (`heard-captions.json`, FLEURS readings heard on an iPhone) and real scripts (`script-tools-corpus.json`).
struct CaptionEmphasisSuggesterTests {
    private func word(_ text: String, _ language: NLLanguage) -> String? {
        CaptionEmphasisSuggester.suggestion(in: text, language: language).map { CaptionText.words(in: text)[$0] }
    }

    /// Whether this system's name tagger hears "Brasil" as a place: the rule marks names the tagger finds, and the tagger is
    /// the OS's (the iPhone 17 simulator on iOS 27 said yes on 08/11 at 03:50 and no from 17:00 on, with the same code).
    private static let taggerHearsBrasil: Bool = {
        let text = "Aqui no Brasil, para o produto"
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.setLanguage(.portuguese, range: text.startIndex..<text.endIndex)
        var place = false
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            if text[range] == "Brasil", tag == .placeName { place = true }
            return true
        }
        return place
    }()

    /// A name the system's tagger doesn't hear is a gap of the OS model, not of the rule: known, and only then.
    private func expectName(_ check: () -> Void) {
        if Self.taggerHearsBrasil { check() } else { withKnownIssue("This system's tagger doesn't hear Brasil as a place", isIntermittent: true, check) }
    }

    @Test(arguments: [
        ("Ganhei R$ 5 mil no primeiro mês", "5"),
        ("Meu canal cresceu 300% esse ano", "300%"),
        ("Estou vendo 3 hábitos ruins que", "3"),
        ("Isso custa 20 reais na feira", "20"),
        ("Esse truque me deixou 3x mais rápido", "3x"),
        ("Aqui no Brasil, para o produto", "Brasil,"),
    ])
    func portugueseLinesWithOneClearWord(line: String, expected: String) {
        if expected == "Brasil," {
            expectName { #expect(word(line, .portuguese) == expected, "\(line)") }
        } else {
            #expect(word(line, .portuguese) == expected, "\(line)")
        }
    }

    @Test(arguments: [
        ("I made $500 in one week", "$500"),
        ("My channel grew 300% this year", "300%"),
        ("I break down 3 common errors", "3"),
        ("This trick saved me 10k views", "10k"),
    ])
    func englishLinesWithOneClearWord(line: String, expected: String) {
        #expect(word(line, .english) == expected, "\(line)")
    }

    /// Incidental numbers, two of a kind, a name cut by the line's end, too short, nothing to go on.
    @Test(arguments: [
        ("Às 7:30 eu já estou na academia", NLLanguage.portuguese),
        ("Acordo às 6 todo santo dia", .portuguese),
        ("Em 2019 eu larguei tudo isso", .portuguese),
        ("No dia 08/11 sai o vídeo novo", .portuguese),
        ("Esse é o passo 1 da rotina", .portuguese),
        ("Fiquei em 2º lugar no campeonato", .portuguese),
        ("Paguei 20 reais e vendi por 50 reais", .portuguese),
        ("em outras partes do Reino", .portuguese),
        ("Mas valem cada centavo.", .portuguese),
        ("Massa fina, muito recheio", .portuguese),
        ("5 dicas", .portuguese),
        ("by 25 to 30 years.", .english),
        ("I wake up at 6 every day", .english),
        ("Back in 2019 I quit my job", .english),
        ("Step 2 is the easy one", .english),
        ("I came 1st in the race", .english),
        ("The thing nobody tells you about", .english),
    ])
    func linesThatStayWithoutAMark(line: String, language: NLLanguage) {
        #expect(CaptionEmphasisSuggester.suggestion(in: line, language: language) == nil, "\(line)")
    }

    /// The heard captions and the scripts, cut into lines as Cue cuts them: never more than one word, never in a short line, and only
    /// the few lines with a clear number, value or name get one.
    @Test func realPortugueseAndEnglishCaptions() throws {
        var lines: [(text: String, language: NLLanguage)] = []
        for reading in try Self.heardReadings() {
            let language: NLLanguage = reading.name.contains("-pt") ? .portuguese : .english
            lines += CaptionBuilder.group(Self.timed(reading)).map { ($0.text, language) }
        }
        for script in try Self.scripts() {
            let language: NLLanguage = script.language == "pt-BR" ? .portuguese : .english
            for sentence in script.text.replacingOccurrences(of: "\n", with: " ").components(separatedBy: CharacterSet(charactersIn: ".!?")) {
                let words = CaptionText.words(in: sentence)
                lines += stride(from: 0, to: words.count, by: 6).map { (words[$0..<min(words.count, $0 + 6)].joined(separator: " "), language) }
            }
        }
        #expect(lines.count > 600)
        var marked: [String: String] = [:]
        for line in lines {
            guard let index = CaptionEmphasisSuggester.suggestion(in: line.text, language: line.language) else { continue }
            let words = CaptionText.words(in: line.text)
            #expect(words.count >= CaptionEmphasisSuggester.shortestLine)
            marked[line.text] = words[index]
        }
        // What the rule picks in these captions: the numbers that carry the line and a name with its comma; "25 to 30 years",
        // "Reino | Unido", "Jean Carlos" and the many lines with nothing clear stay without a mark.
        #expect(marked["Estou vendo 3 hábitos ruins que"] == "3")
        #expect(marked["I break down 3 common errors"] == "3")
        expectName { #expect(marked["Aqui no Brasil, para o produto"] == "Brasil,") }
        #expect(marked["by 25 to 30 years."] == nil)
        #expect(marked["em outras partes do Reino"] == nil)
        #expect(marked["Jean Carlos disse que ela"] == nil)
        #expect(Double(marked.count) / Double(lines.count) < 0.05, "Suggestions stay rare: \(marked.count) of \(lines.count)")
    }

    @Test func aLineWithMarksOfTheCreatorsOrATakenAwaySuggestionGetsNone() {
        var own = CaptionCue(text: "Ganhei R$ 5 mil no primeiro mês", start: 0, end: 2)
        own.emphasis = [5]
        var declined = CaptionCue(text: "Meu canal cresceu 300% esse ano", start: 2, end: 4)
        declined.declinedEmphasis = [3]
        let open = CaptionCue(text: "Isso custa 20 reais na feira", start: 4, end: 6)
        let found = CaptionEmphasisSuggester.suggestions(for: [own, declined, open], language: .portuguese)
        #expect(found == [open.id: 2])
    }

    // MARK: - Fixtures

    private final class BundleToken {}
    private struct Heard: Decodable { let readings: [Reading] }
    private struct Reading: Decodable {
        let name: String
        let words: [[Value]]
    }
    private static func timed(_ reading: Reading) -> [CaptionWord] {
        reading.words.compactMap { values in
            guard values.count == 4, case .text(let text) = values[0], case .number(let start) = values[1],
                  case .number(let end) = values[2] else { return nil }
            return CaptionWord(text: text, start: start, end: end, isEstimated: false)
        }
    }
    private enum Value: Decodable {
        case text(String), number(Double), flag(Bool)
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let flag = try? value.decode(Bool.self) {
                self = .flag(flag)
            } else if let number = try? value.decode(Double.self) {
                self = .number(number)
            } else {
                self = .text(try value.decode(String.self))
            }
        }
    }
    private struct Script: Decodable { let language: String; let text: String }

    private static func heardReadings() throws -> [Reading] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "heard-captions", withExtension: "json"))
        return try JSONDecoder().decode(Heard.self, from: Data(contentsOf: url)).readings
            .filter { $0.name.hasPrefix("human-pt") || $0.name.hasPrefix("human-en") }
    }

    private static func scripts() throws -> [Script] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "script-tools-corpus", withExtension: "json"))
        return try JSONDecoder().decode([Script].self, from: Data(contentsOf: url)).filter { $0.language == "pt-BR" || $0.language == "en-US" }
    }
}
