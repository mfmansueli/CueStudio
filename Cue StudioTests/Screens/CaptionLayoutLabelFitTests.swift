//
//  CaptionLayoutLabelFitTests.swift
//  Cue StudioTests
//

import Testing
import UIKit
@testable import Cue_Studio

/// Caption style › Layout's "Text per caption" (pt "Texto por legenda") and its three choices, measured in each of the app's
/// 20 languages (there is no Finnish) the way the panel draws them (owner, canvas 2 F2: measure it and bring a proposal if it
/// doesn't fit): the name on one line beside "as they were made" across the iPhone SE's panel, and each choice whole in its
/// third of the segmented well (two lines between words, down to 75%, as `WholeWordsLabel` draws it), at the default text
/// size and at the largest one before the accessibility sizes. The widths go to the log ("FIT …") for the report.
@MainActor
@Suite("Caption Layout labels fit")
struct CaptionLayoutLabelFitTests {
    nonisolated static let languages = [
        "ar", "da", "de", "en", "es", "fr", "hi", "id", "it", "ja", "ko", "nb", "nl", "pt", "sv", "th", "tr", "vi", "zh-Hans", "zh-Hant",
    ]

    /// The panel's content on the iPhone SE, the narrowest: 375 pt less 16 pt each side.
    nonisolated static let narrow: CGFloat = 343

    private static func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle(for: CaptionsViewModel.self).path(forResource: language, ofType: "lproj"), "No \(language).lproj")
        return try #require(Bundle(path: path))
    }

    private static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight, size: UIContentSizeCategory) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: size))
        return UIFont.systemFont(ofSize: base.pointSize, weight: weight)
    }

    private static func width(_ text: String, _ font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    @Test(arguments: languages)
    func textPerCaptionFitsInEveryLanguage(_ language: String) throws {
        // English is the catalog's own language: the keys.
        let bundle = language == "en" ? nil : try Self.bundle(language)
        let text = { (key: String) in bundle?.localizedString(forKey: key, value: key, table: nil) ?? key }
        let name = text("Text per caption")
        let detail = text("as they were made")
        let choices = ["One word", "Short phrase", "Two lines"].map(text)
        #expect(language == "en" || name != "Text per caption", "\(language): the translation wasn't found")
        if language == "pt" { #expect(name == "Texto por legenda", "the owner's Portuguese") }

        for size in [UIContentSizeCategory.large, .extraExtraExtraLarge] {
            let nameFont = Self.font(.subheadline, weight: .semibold, size: size)
            let detailFont = Self.font(.caption1, weight: .regular, size: size)
            let segmentFont = Self.font(.footnote, weight: .semibold, size: size)
            let nameWidth = Self.width(name, nameFont)
            let besideDetail = nameWidth + 10 + Self.width(detail, detailFont)
            // Three choices in the well: 3 pt inside each side and between them.
            let segment = (Self.narrow - 6 - 6) / 3
            let widest = choices.map { choice in
                // Its longest word at the smallest it may be drawn, and the whole choice on at most two lines.
                let words = choice.split(separator: " ").map(String.init)
                let longestWord = words.map { Self.width($0, segmentFont) }.max() ?? 0
                return (choice, whole: Self.width(choice, segmentFont), longestWord: longestWord)
            }
            print(
                "FIT \(language) \(size.rawValue): \"\(name)\" \(Int(nameWidth)) pt; beside \"\(detail)\" \(Int(besideDetail)) pt of \(Int(Self.narrow)); "
                    + widest.map { "\"\($0.0)\" \(Int($0.whole)) pt" }.joined(separator: ", ") + " in \(Int(segment)) pt"
            )
            #expect(nameWidth <= Self.narrow, "\(language): \"\(name)\" doesn't fit on one line")
            if size == .large {
                #expect(besideDetail <= Self.narrow, "\(language): \"\(name)\" and \"\(detail)\" don't share the row on the SE")
            }
            for choice in widest {
                #expect(choice.longestWord * 0.75 <= segment, "\(language): a word of \"\(choice.0)\" is cut")
                #expect(choice.whole * 0.75 <= segment * 2, "\(language): \"\(choice.0)\" needs more than two lines")
            }
        }
    }
}
