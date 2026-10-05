//
//  ShareRoute.swift
//  Cue Studio
//

import Foundation

/// How a destination's tile gets the video there, decided before anything is sent.
nonisolated enum ShareRoute: Equatable, Sendable {
    /// TikTok's Share Kit, with the video's identifier in the photo library; TikTok calls back.
    case shareKit
    /// Instagram's documented hand-off (video on the pasteboard, then the Reels or Stories composer opens). Instagram
    /// gives no callback.
    case instagramHandoff(InstagramSurface)
    /// The system share sheet with the file; the app, if it has a share extension, is one of its targets.
    case activitySheet
    /// The video goes to Photos and the platform's app opens so the creator can pick it: the honest fallback when the
    /// platform has no way to take the file directly.
    case saveAndOpen
    /// The video goes to Photos and Cue says so, recommending the creator post it from the app: no integration takes a video from
    /// another app (LinkedIn).
    case saveOnly

    /// The route needs the video in the photo library first (its identifier, or the creator picking it there).
    var needsPhotosCopy: Bool {
        switch self {
        case .shareKit, .saveAndOpen, .saveOnly: true
        case .instagramHandoff, .activitySheet: false
        }
    }
}
