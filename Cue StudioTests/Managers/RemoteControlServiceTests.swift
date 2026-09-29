//
//  RemoteControlServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("RemoteControlService")
struct RemoteControlServiceTests {
    private func makeService() -> (RemoteControlService, FakeRemoteTransport) {
        let transport = FakeRemoteTransport()
        return (RemoteControlService(transport: transport, makeCode: { "ABC234" }), transport)
    }

    // MARK: - Teleprompter

    @Test func connectADeviceShowsACodeAndWaits() {
        let (remote, transport) = makeService()
        remote.startHosting()
        #expect(remote.state == .waiting)
        #expect(remote.code == "ABC234")
        #expect(remote.pairingURL?.absoluteString == "cuestudio://remote?code=ABC234")
        #expect(transport.hostedCodes == ["ABC234"])
    }

    @Test func theDeviceJoiningConnectsAndHearsTheStatus() {
        let (remote, transport) = makeService()
        remote.startHosting()
        transport.emit(.connected(deviceName: "iPad"))
        #expect(remote.state == .connected(deviceName: "iPad"))
        #expect(remote.state.label == "Remote Connected")
        #expect(transport.sentStatuses == [.idle])
    }

    @Test func commandsReachThePrompterWhileItsOpen() {
        let (remote, transport) = makeService()
        remote.startHosting()
        transport.emit(.connected(deviceName: "iPad"))
        var received: [RemoteCommand] = []
        remote.attach(onCommand: { received.append($0) }, status: { .idle })
        transport.emit(.received(.command(.togglePlay)))
        transport.emit(.received(.command(.faster)))
        #expect(received == [.togglePlay, .faster])

        remote.detach()
        transport.emit(.received(.command(.pause)))
        #expect(received == [.togglePlay, .faster])
    }

    @Test func statusIsSentOnlyWhileConnected() {
        let (remote, transport) = makeService()
        remote.startHosting()
        remote.publish(.idle)
        #expect(transport.sent.isEmpty)
    }

    @Test func aLostRemoteCanComeBack() {
        let (remote, transport) = makeService()
        remote.startHosting()
        transport.emit(.connected(deviceName: "iPad"))
        transport.emit(.disconnected)
        #expect(remote.state == .waiting)
        #expect(remote.code == "ABC234")
    }

    // MARK: - Remote

    @Test func joiningWithATypedCode() {
        let (remote, transport) = makeService()
        #expect(remote.join(code: "abc-234"))
        #expect(remote.role == .remote)
        #expect(remote.state == .searching)
        #expect(transport.joinedCodes == ["ABC234"])
        #expect(!remote.join(code: "nope"))
    }

    @Test func theRemoteSendsCommandsOnceConnectedAndShowsTheStatus() {
        let (remote, transport) = makeService()
        remote.join(code: "ABC234")
        remote.send(.play)
        #expect(transport.sentCommands.isEmpty)
        transport.emit(.connected(deviceName: "iPhone"))
        remote.send(.play)
        #expect(transport.sentCommands == [.play])
        let status = RemoteStatus(scriptTitle: "3 habits", isPlaying: true, speed: 0.8, followsVoice: false, progress: 0.2, isRecording: false)
        transport.emit(.received(.status(status)))
        #expect(remote.teleprompterStatus == status)
    }

    @Test func disconnectStopsEverything() {
        let (remote, transport) = makeService()
        remote.startHosting()
        transport.emit(.connected(deviceName: "iPad"))
        remote.disconnect()
        #expect(remote.state == .off)
        #expect(remote.role == nil)
        #expect(remote.code == nil)
        #expect(transport.stopCount >= 2)
    }
}
