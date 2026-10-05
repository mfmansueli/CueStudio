//
//  TikTokShareResultTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Share Kit's answers (OpenSDK 2.x codes) and what Cue makes of each.
@Suite("TikTokShareResult")
struct TikTokShareResultTests {
    @Test func successIsADeliveryNotAPublication() {
        let outcome = TikTokShareResult.outcome(errorCode: 0, shareState: 20000)
        #expect(outcome == .delivered(.tikTokShareKit))
        if case .delivered(let evidence) = outcome { #expect(!evidence.confirmsPublication) }
    }

    @Test func aDraftIsDeliveredToo() {
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 20015) == .delivered(.tikTokShareKit))
    }

    @Test func cancellingIsNotADelivery() {
        #expect(TikTokShareResult.outcome(errorCode: -2, shareState: 20013) == .cancelled)
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 20013) == .cancelled)
        // The SDK's state defaults to "success" when the link has none: the error code decides.
        #expect(TikTokShareResult.outcome(errorCode: -2, shareState: 20000) == .cancelled)
    }

    @Test func aNonZeroErrorWithASuccessStateIsNotASuccess() {
        #expect(TikTokShareResult.outcome(errorCode: -3, shareState: 20000) == .failed(.unknown))
        #expect(TikTokShareResult.outcome(errorCode: 100000, shareState: 20000) == .failed(.unknown))
    }

    @Test func tikTokNotInstalledIsUnavailable() {
        #expect(TikTokShareResult.outcome(errorCode: -3, shareState: 20019) == .unavailable(.appNotInstalled))
    }

    @Test func failuresSayWhichKind() {
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 20005) == .failed(.photosAccess))
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 21003) == .failed(.photosAccess))
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 20007) == .failed(.rejected))
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 20012) == .failed(.rejected))
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 20006) == .failed(.unknown))
        #expect(TikTokShareResult.outcome(errorCode: 0, shareState: 99999) == .failed(.unknown))
    }
}
