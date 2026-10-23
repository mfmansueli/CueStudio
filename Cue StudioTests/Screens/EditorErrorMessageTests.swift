//
//  EditorErrorMessageTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// The creator never reads a framework's code: Cue's messages stay, the system's become plain words, anything else the
/// tool's own words.
@Suite("Editor error messages")
struct EditorErrorMessageTests {
    private let fallback = "Can't add this file"

    @Test func cuesOwnMessagesStay() {
        #expect(EditorErrorMessage.text(for: VoiceOverError.couldNotRecord, otherwise: fallback) == "Couldn't start recording")
    }

    @Test func aFullIPhoneIsSaidSo() {
        let full = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        let underneath = NSError(domain: "PHPhotosErrorDomain", code: 3_164, userInfo: [NSUnderlyingErrorKey: posix])
        for error in [full, underneath] {
            #expect(EditorErrorMessage.text(for: error, otherwise: fallback) == "Not enough space on this iPhone · Free some and try again")
        }
    }

    @Test func aMicrophoneInUseIsSaidSo() {
        let busy = NSError(domain: NSOSStatusErrorDomain, code: AVAudioSession.ErrorCode.insufficientPriority.rawValue)
        #expect(EditorErrorMessage.text(for: busy, otherwise: fallback) == "Another app is using the microphone · Close it and try again")
    }

    @Test func photosThatCantHandOverAFileAreSaidSo() {
        let offline = NSError(domain: "PHPhotosErrorDomain", code: 3_164)
        #expect(EditorErrorMessage.text(for: offline, otherwise: fallback) == "Photos couldn't hand this over · Check your connection and try again")
    }

    @Test func anythingElseIsTheToolsOwnWords() {
        let odd = NSError(domain: "AVFoundationErrorDomain", code: -11_800)
        #expect(EditorErrorMessage.text(for: odd, otherwise: fallback) == fallback)
    }
}
