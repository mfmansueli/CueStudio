//
//  UltraReviewReplyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The polish is read strictly: exactly the three keys with a script in them, or it is a failed polish.
@Suite("Ultra AI review reply")
struct UltraReviewReplyTests {
    @Test func theThreeKeysAreRead() throws {
        let reply = try #require(UltraReviewReply(json: #"{"title":"“Three habits”","script":"  The script.  ","changes":["One", " "]}"#))
        #expect(reply.title == "Three habits" && reply.script == "The script." && reply.changes == ["One"])
    }

    @Test func anythingElseIsAFailedPolish() {
        #expect(UltraReviewReply(json: "The script.") == nil)
        #expect(UltraReviewReply(json: #"{"title":"T","script":"S"}"#) == nil)
        #expect(UltraReviewReply(json: #"{"title":"T","script":"S","changes":[],"rating":9}"#) == nil)
        #expect(UltraReviewReply(json: #"{"title":"T","script":"  ","changes":[]}"#) == nil)
        let many = (0...UltraReviewReply.changeLimit).map { "\"c\($0)\"" }.joined(separator: ",")
        #expect(UltraReviewReply(json: #"{"title":"T","script":"S","changes":[\#(many)]}"#) == nil)
    }
}
