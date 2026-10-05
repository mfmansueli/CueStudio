//
//  DeliveryEvidence.swift
//  Cue Studio
//

import Foundation

/// Proof that a video left Cue. Only a case here can make an export count: opening another app is not one, and
/// neither is a file prepared inside Cue.
nonisolated enum DeliveryEvidence: Codable, Equatable, Hashable, Sendable {
    /// iOS accepted the video into the photo library. `assetID` is the new asset's local identifier.
    case photoLibrary(assetID: String?)
    /// A share-sheet activity finished with `completed == true`. `type` is its `UIActivity.ActivityType` raw value.
    case activity(type: String?)
    /// The video's data was put on the system pasteboard for Instagram's composer and Instagram opened (`InstagramShareManager`). It left
    /// Cue's hands; Instagram answers nothing, so whether it read the video, and whether it is posted, is unknown.
    case pasteboardHandoff
    /// TikTok's Share Kit called back with a success (or "saved as draft") state: TikTok has the video.
    case tikTokShareKit

    /// No platform reports the moment of publication, so no evidence ever proves it: the share sheet finishing says the
    /// file was accepted by an app, Share Kit says TikTok received it and the pasteboard hand-off says Instagram was opened with it,
    /// nothing more. Messages and celebrations must read "shared" or "delivered", never "posted".
    var confirmsPublication: Bool { false }
}
