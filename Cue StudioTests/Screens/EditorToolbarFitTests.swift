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
        // 3.5 pt each side of the words, 2 pt from the tool's edges.
        #expect(EditorToolbarFit.badgeFits(labelWidth: 53, toolWidth: 64))
        #expect(!EditorToolbarFit.badgeFits(labelWidth: 54, toolWidth: 64))
    }
}

/// The scope badge in the 20 languages: its short words fit over the narrowest tool of every height class (so it never reaches
/// a neighbour), and the long ones show where a tool at most `badgeGrowth` wider has room for them.
@Suite("Toolbar scope badge")
@MainActor
struct EditorToolbarBadgeTests {
    private static func strings(_ localization: String) -> [String: String] {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: localization),
              let table = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
        return table
    }

    @Test func oneFormOnTheWholeBar() {
        // "WHOLE VIDEO" (65 pt) over regular tools (68): they grow to 76, within the 12 pt they may; a tool already wider keeps
        // its width.
        #expect(EditorToolbarFit.longBadgeFits(labelWidth: 65, toolWidths: [68, 68, 79], preferred: 68))
        // Words that would need a tool 14 pt wider: the short one, on every tool.
        #expect(!EditorToolbarFit.longBadgeFits(labelWidth: 71, toolWidths: [68, 90], preferred: 68))
    }

    @Test(arguments: CueLanguage.allCases)
    func theBadgeFitsItsToolInEveryLanguage(language: CueLanguage) {
        let table = Self.strings(language.interfaceLocalization)
        let locale = Locale(identifier: language.interfaceLocalization)
        let long = (table["Whole video"] ?? "Whole video").uppercased(with: locale)
        let short = (table["All"] ?? "All").uppercased(with: locale)
        var report: [String] = []
        for heightClass in [EditorHeightClass.regular, .compact, .veryCompact] {
            let padding: CGFloat = heightClass.toolbarShowsLabels ? 4 : 0
            let narrowest = heightClass.toolbarItemMinimumWidth + padding
            let preferred = heightClass.toolbarItemWidth + padding
            #expect(
                EditorToolbarFit.badgeFits(labelWidth: EditorToolbarBadge.width(of: short), toolWidth: narrowest),
                "\(language.interfaceLocalization): “\(short)” is wider than a \(narrowest) pt tool"
            )
            let longWidth = EditorToolbarBadge.width(of: long)
            let showsLong = EditorToolbarFit.longBadgeFits(labelWidth: longWidth, toolWidths: [preferred], preferred: preferred)
            if showsLong {
                #expect(EditorToolbarFit.badgeRoom(labelWidth: longWidth) <= preferred + EditorToolbarFit.badgeGrowth)
            }
            report.append("\(language.interfaceLocalization) \(heightClass) \(preferred) pt: \(showsLong ? long : short) (long \(longWidth) pt)")
        }
        Attachment.record(report.joined(separator: "\n"), named: "badge-\(language.interfaceLocalization).txt")
    }
}
