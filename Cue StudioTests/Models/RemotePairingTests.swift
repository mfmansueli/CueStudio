//
//  RemotePairingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("RemotePairing")
struct RemotePairingTests {
    @Test func codesAreSixUnambiguousCharacters() {
        for _ in 0..<50 {
            let code = RemotePairing.makeCode()
            #expect(code.count == 6)
            #expect(code.allSatisfy(RemotePairing.alphabet.contains))
            #expect(!code.contains("0") && !code.contains("O") && !code.contains("1") && !code.contains("I"))
        }
    }

    @Test func theQRCodeLinkCarriesTheCode() throws {
        let url = try #require(RemotePairing.url(for: "ABC234"))
        #expect(url.absoluteString == "cuestudio://remote?code=ABC234")
        #expect(RemotePairing.code(from: url) == "ABC234")
    }

    @Test func otherLinksAreNotPairingCodes() throws {
        #expect(RemotePairing.code(from: try #require(URL(string: "cuestudio://script?code=ABC234"))) == nil)
        #expect(RemotePairing.code(from: try #require(URL(string: "https://remote?code=ABC234"))) == nil)
    }

    @Test func typedCodesForgiveCaseSpacesAndDashes() {
        #expect(RemotePairing.code(from: "abc 234") == "ABC234")
        #expect(RemotePairing.code(from: "ABC-234") == "ABC234")
        #expect(RemotePairing.code(from: "ABC23") == nil)
        #expect(RemotePairing.code(from: "ABC230") == nil)
    }

    @Test func codesReadInTwoHalves() {
        #expect(RemotePairing.display("ABC234") == "ABC 234")
    }

    @Test func messagesSurviveTheTrip() throws {
        let status = RemoteStatus(scriptTitle: "3 habits", isPlaying: true, speed: 0.9, followsVoice: false, progress: 0.4, isRecording: true)
        for message in [RemoteMessage.command(.faster), .status(status)] {
            #expect(try RemoteMessage.decoded(from: message.encoded()) == message)
        }
    }
}
