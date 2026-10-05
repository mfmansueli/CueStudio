//
//  InstagramSharing.swift
//  Cue Studio
//

import Foundation

/// Instagram's documented hand-off to the Reels and Stories composers.
protocol InstagramSharing: AnyObject {
    /// Puts the video on the pasteboard the way Meta documents and opens the composer. The outcome is `.opened` when the
    /// composer opened: Instagram reports nothing back, so it is never `.delivered`.
    func share(videoAt url: URL, to surface: InstagramSurface, appID: String) async -> ShareOutcome
}
