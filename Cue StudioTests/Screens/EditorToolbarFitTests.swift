//
//  EditorToolbarFitTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The toolbar's widths (`EditorToolbarFit`): tools that fit keep the class's width; tools that only just overflow (a picked
/// Blur area's four on a 6.1" iPhone: Edit · Track · Replay · Add area, then Delete pinned) narrow so all show whole, never
/// under the minimum or their label; too many keep their width and scroll.
@Suite("Toolbar widths")
struct EditorToolbarFitTests {
    /// The regular class with labels: 64 pt plus 2 pt each side, at least 54 plus 2 each side, a narrowed label keeps 6 pt
    /// around it.
    private func widths(_ labels: [CGFloat], available: CGFloat) -> [CGFloat] {
        EditorToolbarFit.widths(labels: labels, preferred: 68, minimum: 58, padding: 4, breathing: 10, available: available)
    }

    @Test func toolsThatFitKeepTheirWidth() {
        #expect(widths([34, 35, 32], available: 300) == [68, 68, 68])
        // A long label makes its tool wider, as before.
        #expect(widths([34, 70], available: 300) == [68, 74])
    }

    @Test func aPickedBlurAreasFourToolsShowWholeOnA61InchIPhone() {
        // iPhone 15 Pro, 393 pt: the back button (58) and Delete pinned (76) leave 259, less 8 of padding.
        let available: CGFloat = 393 - 58 - 76 - 8
        let labels: [CGFloat] = [34, 35, 32, 54] // Editar · Seguir · Rever · Nova área
        let fitted = widths(labels, available: available)
        #expect(abs(fitted.reduce(0, +) - available) < 0.01, "they fill the room exactly, nothing hidden under Delete")
        for (width, label) in zip(fitted, labels) {
            #expect(width >= 58 && width >= label + 10)
        }
    }

    @Test func tooManyToolsKeepTheirWidthAndScroll() {
        let labels = Array(repeating: CGFloat(40), count: 12)
        #expect(widths(labels, available: 259) == Array(repeating: 68, count: 12))
        // A scrolling bar's long labels keep the width they always had (where each tool stops after a swipe doesn't move).
        #expect(widths([70, 40, 40, 40, 40], available: 259) == [74, 68, 68, 68, 68])
    }

    @Test func onlyAnItemsOwnToolsNarrowToShowWholeBesideDelete() {
        // A picked Blur area's four, then the editor's other tools after the thin line: the four still fill the room, and the
        // others wait past the edge at their width.
        let available: CGFloat = 393 - 58 - 76 - 8
        let labels: [CGFloat] = [34, 35, 32, 54, 40, 40, 70]
        let fitted = EditorToolbarFit.widths(
            labels: labels, fittingFirst: 4, preferred: 68, minimum: 58, padding: 4, breathing: 10, available: available
        )
        #expect(abs(fitted.prefix(4).reduce(0, +) - available) < 0.01)
        #expect(Array(fitted.dropFirst(4)) == [68, 68, 74])
        // Nothing of its own (the main video's area keeps its few): the same widths as a bar of only those tools.
        #expect(
            EditorToolbarFit.widths(labels: [34, 35], fittingFirst: 2, preferred: 68, minimum: 58, padding: 4, breathing: 10, available: 300)
                == widths([34, 35], available: 300)
        )
    }

    @Test func theScopeBadgeKeepsClearOfTheNextTool() {
        // 3.5 pt each side of the words, 1 pt from the tool's edges.
        #expect(EditorToolbarFit.badgeFits(labelWidth: 55, toolWidth: 64))
        #expect(!EditorToolbarFit.badgeFits(labelWidth: 56, toolWidth: 64))
    }
}

/// The scope badge in the 20 languages: "ALL" in each one is never wider than the narrowest tool of any height class, so it
/// never reaches a neighbour.
@Suite("Toolbar scope badge")
@MainActor
struct EditorToolbarBadgeTests {
    private static func strings(_ localization: String) -> [String: String] {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: localization),
              let table = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
        return table
    }

    @Test(arguments: CueLanguage.allCases)
    func theBadgeFitsItsToolInEveryLanguage(language: CueLanguage) {
        let words = (Self.strings(language.interfaceLocalization)["All"] ?? "All")
            .uppercased(with: Locale(identifier: language.interfaceLocalization))
        let width = EditorToolbarBadge.width(of: words)
        var report: [String] = []
        for heightClass in [EditorHeightClass.regular, .compact, .veryCompact] {
            let narrowest = heightClass.toolbarItemMinimumWidth + (heightClass.toolbarShowsLabels ? 4 : 0)
            #expect(
                EditorToolbarFit.badgeFits(labelWidth: width, toolWidth: narrowest),
                "\(language.interfaceLocalization): “\(words)” is wider than a \(narrowest) pt tool"
            )
            report.append("\(language.interfaceLocalization) \(heightClass) narrowest \(narrowest) pt: \(words) (\(width) pt)")
        }
        Attachment.record(report.joined(separator: "\n"), named: "badge-\(language.interfaceLocalization).txt")
    }
}
