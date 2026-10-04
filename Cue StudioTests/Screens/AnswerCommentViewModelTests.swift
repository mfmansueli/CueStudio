//
//  AnswerCommentViewModelTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// "Answer a comment": read it, confirm it, write the answer.
@MainActor
@Suite("AnswerCommentViewModel")
struct AnswerCommentViewModelTests {
    private final class StubRecognizer: TextRecognizing {
        var text = "@maya\nWhy do you wake up so early?\n2h\nReply"
        func recognizeText(in images: [CGImage]) async throws -> ImportedDocument {
            ImportedDocument(title: "", text: text, kind: "Photo")
        }
    }

    private func make(clipboard: String? = nil, started: @escaping (ScriptComment, Platform) -> Void = { _, _ in }) -> AnswerCommentViewModel {
        AnswerCommentViewModel(defaultPlatform: .tiktok, recognizer: StubRecognizer(), clipboard: { clipboard }, starter: started)
    }

    @Test func pastedWordsGoToTheConfirmStep() {
        let model = make(clipboard: "@leo How do you stay consistent?")
        model.pasteFromClipboard()
        #expect(model.step == .confirm && model.author == "@leo" && model.text == "How do you stay consistent?")
    }

    @Test func nothingCopiedSaysSoAndStaysOnTheFirstStep() {
        let model = make(clipboard: nil)
        model.pasteFromClipboard()
        #expect(model.step == .choose && model.failure != nil)
    }

    @Test func theCreatorCanChangeEverythingBeforeItIsWritten() {
        var written: (ScriptComment, Platform)?
        let model = make(clipboard: "@leo Why?") { written = ($0, $1) }
        model.pasteFromClipboard()
        model.author = "maya"
        model.text = "Why mornings?"
        model.platform = .reels
        model.write()
        #expect(written?.0 == ScriptComment(author: "@maya", text: "Why mornings?", platform: .reels))
        #expect(written?.1 == .reels)
    }

    @Test func nothingIsWrittenWithoutWords() {
        var wrote = false
        let model = make(clipboard: "@leo ") { _, _ in wrote = true }
        model.pasteFromClipboard()
        model.text = "   "
        #expect(!model.canWrite)
        model.write()
        #expect(!wrote)
    }

    @Test func theIdeaTheModelGetsNamesTheCommentAndItsAuthor() {
        let idea = AnswerCommentViewModel.idea(for: ScriptComment(author: "@maya", text: "Why so early?"))
        #expect(idea.contains("@maya") && idea.contains("Why so early?"))
    }
}
