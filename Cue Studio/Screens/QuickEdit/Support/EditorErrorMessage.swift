//
//  EditorErrorMessage.swift
//  Cue Studio
//

import AVFAudio
import Foundation

/// What the creator reads when something picked or recorded couldn't be taken in: Cue's own messages as they are, the
/// system's in plain words (a full iPhone, a file Photos couldn't hand over, the microphone taken by another app), and the
/// tool's own words otherwise, never a framework's code ("The operation couldn't be completed (OSStatus error 561017449)").
nonisolated enum EditorErrorMessage {
    static func text(for error: any Error, otherwise fallback: String) -> String {
        if String(reflecting: type(of: error)).hasPrefix("Cue_Studio."), let described = (error as? LocalizedError)?.errorDescription {
            return described
        }
        let chain = errors(under: error as NSError)
        if chain.contains(where: isOutOfSpace) {
            return String(localized: "Not enough space on this iPhone · Free some and try again")
        }
        if chain.contains(where: { $0.domain == NSOSStatusErrorDomain && $0.code == AVAudioSession.ErrorCode.insufficientPriority.rawValue }) {
            return String(localized: "Another app is using the microphone · Close it and try again")
        }
        if chain.contains(where: { $0.domain == "PHPhotosErrorDomain" || $0.domain == NSURLErrorDomain }) {
            return String(localized: "Photos couldn't hand this over · Check your connection and try again")
        }
        return fallback
    }

    /// The error and the ones under it, outermost first.
    private static func errors(under error: NSError) -> [NSError] {
        var chain = [error]
        while let next = chain.last?.userInfo[NSUnderlyingErrorKey] as? NSError, chain.count < 8 { chain.append(next) }
        return chain
    }

    private static func isOutOfSpace(_ error: NSError) -> Bool {
        (error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError)
            || (error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC))
    }
}
