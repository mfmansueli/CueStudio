//
//  QuickEditDraftSaveFailure.swift
//  Cue Studio
//

import Foundation

/// Why a draft couldn't be written, as far as the creator can act on it: a full iPhone, or anything else (which Cue tries again
/// without blaming the space).
nonisolated enum QuickEditDraftSaveFailure: Error, Sendable, Equatable {
    case noSpace
    case other

    init(_ error: any Error) {
        self = Self.isNoSpace(error as NSError) ? .noSpace : .other
    }

    private static func isNoSpace(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain, error.code == NSFileWriteOutOfSpaceError { return true }
        if error.domain == NSPOSIXErrorDomain, error.code == Int(ENOSPC) || error.code == Int(EDQUOT) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError { return isNoSpace(underlying) }
        return false
    }
}
