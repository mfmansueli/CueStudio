//
//  ScriptFailureNoticeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A failed AI write: its words never end in "· Try again" (that is the toast's button), and the button only comes where asking again can help.
@Suite("Script failure notice")
struct ScriptFailureNoticeTests {
    @Test func theWordsSayWhatHappenedWithoutTryAgain() {
        #expect(ScriptFailureNotice.message(for: ScriptAIError.emptyResponse) == "Couldn’t draft it")
        #expect(ScriptFailureNotice.message(for: URLError(.timedOut)) == "Couldn’t draft it")
        #expect(ScriptFailureNotice.message(for: UltraError.draftFailed(.timedOut)) == "Ultra AI couldn’t draft it")
        #expect(ScriptFailureNotice.message(for: ScriptAIError.unsupportedLanguage) == ScriptAIError.unsupportedLanguage.localizedDescription)
    }

    @Test func tryAgainOnlyWhereAskingAgainCanHelp() {
        #expect(ScriptFailureNotice.isWorthRetrying(ScriptAIError.emptyResponse))
        #expect(ScriptFailureNotice.isWorthRetrying(UltraError.draftFailed(.timedOut)))
        #expect(ScriptFailureNotice.isWorthRetrying(UltraError.fitFailed(.provider)))
        // The internet is off: the words already say so, and the same request would meet it again.
        #expect(!ScriptFailureNotice.isWorthRetrying(UltraError.draftFailed(.unreachable)))
        #expect(!ScriptFailureNotice.isWorthRetrying(UltraError.noScriptsLeft))
        #expect(!ScriptFailureNotice.isWorthRetrying(ScriptAIError.unsupportedLanguage))
        #expect(!ScriptFailureNotice.isWorthRetrying(CancellationError()))
    }
}
