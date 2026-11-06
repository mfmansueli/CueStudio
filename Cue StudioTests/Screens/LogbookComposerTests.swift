//
//  LogbookComposerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Logbook's field: what a line break means (`LogbookComposerInput`) and what the line over it says (`LogbookComposerStatus`).
@MainActor
@Suite("Logbook composer")
struct LogbookComposerTests {
    // MARK: - Return and pasted lines

    @Test func returnSavesTheIdeaWhereverTheCaretWas() {
        #expect(LogbookComposerInput.change(from: "Slow mornings", to: "Slow mornings\n") == .save("Slow mornings"))
        #expect(LogbookComposerInput.change(from: "Slow mornings", to: "Slow\n mornings") == .save("Slow mornings"))
        #expect(LogbookComposerInput.change(from: "", to: "\n") == .save(""))
        // Letters and Return in one update, or autocorrect fixing the last word as Return is pressed.
        #expect(LogbookComposerInput.change(from: "Swipe me a", to: "Swipe me away\n") == .save("Swipe me away"))
        #expect(LogbookComposerInput.change(from: "Slow mornigns", to: "Slow mornings\n") == .save("Slow mornings"))
    }

    @Test func pastedLinesStayAsOneParagraphAndWait() {
        #expect(LogbookComposerInput.change(from: "", to: "Three habits\nthat changed\n\nmy mornings") == .replace("Three habits that changed my mornings"))
        #expect(LogbookComposerInput.change(from: "Idea: ", to: "Idea: one\r\ntwo") == .replace("Idea: one two"))
    }

    @Test func typingIsLeftAlone() {
        #expect(LogbookComposerInput.change(from: "Slow", to: "Slow ") == .keep)
        #expect(LogbookComposerInput.change(from: "", to: "") == .keep)
    }

    // MARK: - The line over the field

    private func status(
        holding: Bool = true, locked: Bool = false, starting: Bool = false, _ state: DictationState, _ notice: DictationNotice? = nil
    ) -> LogbookComposerStatus? {
        .current(isHolding: holding, isLocked: locked, isStarting: starting, state: state, notice: notice)
    }

    @Test func aHoldSaysItListensAndATapSaysHowToFinish() {
        #expect(status(.listening) == .listening)
        #expect(status(starting: true, .idle) == .listening)
        #expect(status(locked: true, .listening) == .tapToFinish)
        #expect(status(.listening)?.isListening == true)
    }

    /// The microphone is off for Cue: with the finger still down, the line says why and the button doesn't pretend to listen.
    @Test func aHoldThatCantReachTheMicrophoneSaysWhyAtOnce() {
        let line = status(.idle, .microphoneDenied)
        #expect(line == .notice(.microphoneDenied))
        #expect(line?.isListening == false)
        #expect(line?.isWarning == true)
        #expect(line?.offersSettings == true)
        #expect(status(.idle, .unavailable(.noRecognition))?.offersSettings == false)
    }

    @Test func theFirstDownloadOfTheLanguageIsSaid() {
        let downloading = status(locked: true, .preparing(.downloading(.thai, progress: 0.4)))
        #expect(downloading == .downloading(progress: 0.4))
        #expect(downloading?.isListening == true)
        #expect(status(.preparing(.downloading(nil, progress: nil))) == .downloading(progress: nil))
        #expect(status(.preparing(.preparing)) == .listening, "A model already here is ready in a moment: no line flashing by")
    }

    @Test func atRestTheLineIsOnlyAReason() {
        #expect(status(holding: false, .idle) == nil)
        #expect(status(holding: false, .idle, .nothingHeard) == .notice(.nothingHeard))
        #expect(status(holding: false, .idle, .interrupted)?.identifier == "logbook.status")
        #expect(status(locked: true, .listening)?.identifier == "logbook.tapToFinish")
    }
}
