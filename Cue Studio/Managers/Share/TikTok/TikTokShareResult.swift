//
//  TikTokShareResult.swift
//  Cue Studio
//

import Foundation

/// What TikTok's Share Kit answered, as plain numbers (no SDK type), mapped to what Cue tells the creator. The codes are
/// the SDK's `TikTokShareResponseErrorCode` and `TikTokShareResponseState`.
///
/// The SDK's `shareState` defaults to success when the callback has none, so the error code is read first: a success is
/// `errorCode == 0` *and* `shareState == 20000`.
nonisolated enum TikTokShareResult {
    private static let successState = 20000
    private static let cancelledStates: Set<Int> = [20013]
    private static let draftState = 20015
    private static let notInstalledState = 20019
    private static let noPhotoPermissionStates: Set<Int> = [20005, 21001, 21003]
    private static let rejectedStates: Set<Int> = [20007, 20008, 20010, 20011, 20012, 20016]
    private static let cancelledErrorCode = -2

    static func outcome(errorCode: Int, shareState: Int) -> ShareOutcome {
        if errorCode == cancelledErrorCode || cancelledStates.contains(shareState) { return .cancelled }
        if shareState == notInstalledState { return .unavailable(.appNotInstalled) }
        guard errorCode == 0 else { return .failed(.unknown) }
        switch shareState {
        // TikTok has the video: posted or kept as a draft is the creator's call there, and TikTok doesn't say which.
        case successState, draftState: return .delivered(.tikTokShareKit)
        case _ where noPhotoPermissionStates.contains(shareState): return .failed(.photosAccess)
        case _ where rejectedStates.contains(shareState): return .failed(.rejected)
        default: return .failed(.unknown)
        }
    }
}
