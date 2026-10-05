//
//  TikTokShareManager.swift
//  Cue Studio
//

import Foundation
import TikTokOpenSDKCore
import TikTokOpenShareSDK

/// The only file that knows TikTok's SDK (OpenSDK 2.x, Share Kit). It sends the library identifier of a video Cue just
/// saved; TikTok's app reads the video from Photos itself, so Cue needs no more than the add-only access it already has
/// (TikTok answers with a "no photo library permission" state when *its* access is missing).
@MainActor
final class TikTokShareManager: TikTokSharing {
    /// Share Kit calls back through a universal link; the request has to stay alive until it does.
    private var request: TikTokShareRequest?
    private var pending: (@MainActor @Sendable (ShareOutcome) -> Void)?

    func share(assetID: String, redirectURI: String, finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void) -> Bool {
        let request = TikTokShareRequest(localIdentifiers: [assetID], mediaType: .video, redirectURI: redirectURI)
        self.request = request
        pending = finished
        let sent = request.send(Self.responseHandler { [weak self] outcome in self?.finish(with: outcome) })
        if !sent {
            self.request = nil
            pending = nil
        }
        return sent
    }

    func handleCallback(_ url: URL) -> Bool {
        TikTokURLHandler.handleOpenURL(url)
    }

    /// One callback ends the request; a second (a link delivered twice) finds nothing waiting.
    private func finish(with outcome: ShareOutcome) {
        guard let pending else { return }
        self.pending = nil
        request = nil
        pending(outcome)
    }

    /// Built outside the main actor: the SDK calls it from its own code, and a closure made in a `@MainActor` method would
    /// assert that isolation at the call (it aborts under Swift 6 when the call isn't on the main queue). It hops to the
    /// main actor itself.
    private nonisolated static func responseHandler(_ deliver: @escaping @MainActor @Sendable (ShareOutcome) -> Void) -> (TikTokBaseResponse) -> Void {
        { response in
            guard let response = response as? TikTokShareResponse else { return }
            let outcome = TikTokShareResult.outcome(errorCode: response.errorCode.rawValue, shareState: response.shareState.rawValue)
            Task { @MainActor in deliver(outcome) }
        }
    }
}
