//
//  RemoteCipherTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("RemoteCipher")
struct RemoteCipherTests {
    @Test func theSameCodeOpensWhatItSealed() throws {
        let message = Data(#"{"command":"play"}"#.utf8)
        let sealed = try RemoteCipher(code: "ABC234").seal(message)
        #expect(sealed != message)
        #expect(try RemoteCipher(code: "ABC234").open(sealed) == message)
    }

    @Test func anotherCodeCantOpenIt() throws {
        let sealed = try RemoteCipher(code: "ABC234").seal(Data("play".utf8))
        #expect(throws: (any Error).self) { try RemoteCipher(code: "ABC235").open(sealed) }
    }

    @Test func aChangedFrameIsRejected() throws {
        var sealed = try RemoteCipher(code: "ABC234").seal(Data("play".utf8))
        sealed[sealed.startIndex + 14] ^= 0x01
        #expect(throws: (any Error).self) { try RemoteCipher(code: "ABC234").open(sealed) }
    }

    @Test func theServiceNameComesFromTheCodeButDoesNotShowIt() {
        let name = RemoteCipher(code: "ABC234").serviceName
        #expect(name == RemoteCipher(code: "ABC234").serviceName)
        #expect(name != RemoteCipher(code: "ABC235").serviceName)
        #expect(!name.contains("ABC234"))
        // Bonjour names can be at most 63 bytes.
        #expect(name.utf8.count <= 63)
    }
}
