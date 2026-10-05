//
//  TikTokSharing.swift
//  Cue Studio
//

import Foundation

/// TikTok's Share Kit, behind a protocol: no view or view model imports the SDK.
protocol TikTokSharing: AnyObject {
    /// Asks TikTok to take the video that is in the photo library under `assetID`. False when the request could not be sent
    /// (then `finished` is never called). Otherwise `finished` is called once, when TikTok calls back.
    func share(assetID: String, redirectURI: String, finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void) -> Bool

    /// Passes TikTok's callback (a universal link) to the SDK. True when it was TikTok's.
    func handleCallback(_ url: URL) -> Bool
}
