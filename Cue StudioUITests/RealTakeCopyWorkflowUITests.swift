//
//  RealTakeCopyWorkflowUITests.swift
//  Cue StudioUITests
//

import XCTest

/// A talking head edited end to end on a COPY of one of the creator's own takes, in memory (`-uiTestRealTake`): the take itself
/// is never changed and nothing goes to Photos. Pauses out, captions heard from the real voice, a title styled and Style all,
/// then out of the editor and back in (the draft keeps all of it), and Done shows the real size without exporting (canvas 2,
/// delivery 11). Opt-in on an iPhone:
/// `CUE_DEVICE=… TEST_RUNNER_CUE_REAL_TAKE=<file name in Takes> scripts/test.sh device-ui RealTakeCopyWorkflowUITests`.
@MainActor
final class RealTakeCopyWorkflowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testATalkingHeadOnACopyLeavesAndComesBackWhole() throws {
        guard let take = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_REAL_TAKE to a take's file name on the iPhone (one with speech)")
        }
        // A take recorded without a script (`TEST_RUNNER_CUE_REAL_TAKE_UNSCRIPTED=1`) plays as one, with the iPhone's own languages.
        let unscripted = ProcessInfo.processInfo.environment["CUE_REAL_TAKE_UNSCRIPTED"] != nil
        let app = unscripted
            ? EditorApp.open(appLanguage: "en", arguments: ["-uiTestRealTake", take, "-uiTestRealTakeUnscripted"])
            : EditorApp.open(arguments: ["-uiTestRealTake", take])
        let flow = CreatorWorkflow("real-take-copy", app: app)
        let start = Date()
        let full = EditorApp.length(app)
        print("CREATOR STEP real-take-copy · length \(full)")
        EditorApp.capture(app, "real-take-opened")

        flow.step("Clean up › Pauses")
        flow.tool("pauses")
        let apply = app.buttons["edit.pauses.apply"]
        let none = app.descendants(matching: .any)["edit.pauses.empty"]
        _ = apply.exists(within: 60) || none.exists
        if apply.exists, apply.isEnabled {
            flow.tap(apply, apply.label)
            XCTAssertTrue(flow.toastSays("Removed", timeout: 10), "No toast after removing the pauses")
        } else {
            print("CREATOR STEP real-take-copy · no pauses to remove")
        }
        closePanel(app)
        XCTAssertTrue(flow.isOnMainTools(), "Clean up didn't come back to the main tools")
        let cleaned = EditorApp.length(app)

        flow.step("Captions from the real voice")
        flow.tool("captions")
        let make = app.buttons["edit.captionsMakeButton"]
        if make.exists(within: 5) { flow.tap(make, "Make captions") }
        let line = app.descendants(matching: .any)["edit.captionLine.0"]
        XCTAssertTrue(line.exists(within: 120), "No caption line from the real voice in 2 minutes")
        let heard = line.label
        print("CREATOR STEP real-take-copy · first line: \(heard)")
        EditorApp.capture(app, "real-take-captions")
        closePanel(app)

        flow.step("Text › Title, then Style all")
        flow.tool("text")
        flow.tool("title")
        let panel = app.descendants(matching: .any)["edit.panel.textStyle"]
        XCTAssertTrue(flow.waits(for: panel, "Text style"), "Text › Title didn't open Text style")
        EditorApp.capture(app, "real-take-title")
        closePanel(app)
        flow.tool("text")
        flow.tool("styleAll")
        XCTAssertTrue(flow.waits(for: panel, "Text style"), "Style all didn't open Text style")
        EditorApp.capture(app, "real-take-style-all")
        closePanel(app)

        flow.step("‹ out of the editor, Edit again")
        let edited = EditorApp.length(app)
        flow.tap(app.buttons["edit.backButton"], "‹ out of the editor")
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(flow.waits(for: edit, timeout: 10, "the review"), "‹ didn't leave the editor")
        flow.tap(edit, "Edit")
        EditorApp.waitUntilReady(app)
        XCTAssertEqual(EditorApp.length(app), edited, "The length didn't come back with the draft")
        if cleaned != full { XCTAssertNotEqual(EditorApp.length(app), full, "The pauses came back") }
        flow.tool("captions")
        XCTAssertTrue(line.exists(within: 10), "The captions didn't come back with the draft")
        XCTAssertEqual(line.label, heard, "The first caption line changed")
        closePanel(app)
        EditorApp.capture(app, "real-take-back")

        flow.step("Done shows the real size")
        flow.tap(app.buttons["edit.doneButton"], "Done")
        let options = app.descendants(matching: .any)["edit.done.exportOptions"]
        XCTAssertTrue(options.exists(within: 10), "Done has no export options line")
        print("CREATOR STEP real-take-copy · Done says: \(options.label)")
        EditorApp.capture(app, "real-take-done")
        print("CREATOR STEP real-take-copy · whole flow took \(Int(Date().timeIntervalSince(start))) s")
        flow.report()
    }

    /// The same copy as a take with no script linked (`-uiTestRealTakeUnscripted`), with the iPhone's own languages (the interface
    /// in English through `-uiTestAppLanguage`, not by changing the iPhone's): captions guess the language spoken and have to be
    /// in it. `TEST_RUNNER_CUE_REAL_TAKE_LANGUAGE=pt` (or `en`, `es`) is the language the take is spoken in: most of the first
    /// lines' words are that language's commonest words, more than any other's.
    func testCaptionsOfARealTakeWithoutAScriptAreInTheLanguageSpoken() throws {
        guard let take = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_REAL_TAKE to a take's file name on the iPhone (one with speech)")
        }
        let app = EditorApp.open(appLanguage: "en", arguments: ["-uiTestRealTake", take, "-uiTestRealTakeUnscripted"])
        let flow = CreatorWorkflow("real-take-unscripted", app: app)
        flow.step("Captions on Auto, no script")
        flow.tool("captions")
        let make = app.buttons["edit.captionsMakeButton"]
        if make.exists(within: 5) { flow.tap(make, "Make captions") }
        let first = app.descendants(matching: .any)["edit.captionLine.0"]
        XCTAssertTrue(first.exists(within: 120), "No caption line from the real voice in 2 minutes")
        let lines = (0..<6).compactMap { index -> String? in
            let line = app.descendants(matching: .any)["edit.captionLine.\(index)"]
            guard line.exists else { return nil }
            // "00:01.6 → 00:04.3, 2.7s, the words": the words after the times.
            return line.label.components(separatedBy: ", ").dropFirst(2).joined(separator: ", ")
        }
        let language = app.buttons["edit.captionsLanguage"].value as? String ?? ""
        print("CREATOR STEP real-take-unscripted · language chip: \(language) · lines: \(lines)")
        EditorApp.capture(app, "real-take-unscripted-captions")
        guard let spoken = ProcessInfo.processInfo.environment["CUE_REAL_TAKE_LANGUAGE"], let common = Self.commonWords[spoken] else { return }
        let words = lines.joined(separator: " ").lowercased()
            .components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        let hits = words.filter(common.contains).count
        // Another language's commonest words, for comparison: the language spoken has to lead.
        let others = Self.commonWords.filter { $0.key != spoken }.mapValues { list in words.filter(list.contains).count }
        print("CREATOR STEP real-take-unscripted · \(hits) of \(words.count) words are common \(spoken) words; others: \(others)")
        XCTAssertGreaterThanOrEqual(Double(hits), Double(words.count) * 0.15, "The captions don't read as \(spoken): \(lines)")
        XCTAssertTrue(others.values.allSatisfy { $0 < hits }, "Another language reads as well as \(spoken): \(others) · \(lines)")
        XCTAssertTrue(language.hasPrefix("Auto · "), "The language chip doesn't say the language heard: \(language)")
    }

    /// Each language's commonest short words: a good share of any stretch of speech in it, fewer in the others.
    private static let commonWords: [String: Set<String>] = [
        "pt": [
            "que", "de", "o", "a", "e", "é", "não", "um", "uma", "do", "da", "em", "para", "com", "eu", "você", "isso", "se", "os", "as",
            "no", "na", "mais", "mas", "por", "como", "tá", "aqui", "esse", "essa", "ele", "ela", "vai", "ser", "tem", "muito",
        ],
        "en": [
            "the", "a", "and", "to", "of", "i", "you", "it", "is", "that", "in", "this", "we", "so", "for", "on", "with", "but",
            "be", "are", "was", "what", "just", "my", "your", "can", "do", "not", "have", "like",
        ],
        "es": [
            "que", "de", "el", "la", "y", "a", "en", "no", "un", "una", "es", "lo", "los", "las", "por", "con", "para", "se",
            "pero", "más", "como", "yo", "tú", "esto", "muy", "hay", "del", "al",
        ],
    ]

    /// ✓ on whatever panel is open, then back to the main tools.
    private func closePanel(_ app: XCUIApplication) {
        let apply = app.buttons["edit.panel.apply"]
        if apply.exists(within: 2) { apply.tap() }
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }
    }
}
