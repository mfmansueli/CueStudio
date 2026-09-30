//
//  NearbyLinkTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Both ends of the remote link in one process, over real Bonjour on this Mac's network.
@Suite("NearbyLink", .serialized, .timeLimit(.minutes(1)))
struct NearbyLinkTests {
    @Test func aRemoteWithTheCodeConnectsAndControlsTheTeleprompter() async throws {
        let code = RemotePairing.makeCode()
        let (hostEvents, hostSink) = AsyncStream.makeStream(of: RemoteTransportEvent.self)
        let (remoteEvents, remoteSink) = AsyncStream.makeStream(of: RemoteTransportEvent.self)
        let host = NearbyLink(hosting: true, code: code, deviceName: "Teleprompter") { hostSink.yield($0) }
        let remote = NearbyLink(hosting: false, code: code, deviceName: "Remote") { remoteSink.yield($0) }
        defer {
            host.stop()
            remote.stop()
        }
        host.start()
        remote.start()
        var fromHost = hostEvents.makeAsyncIterator()
        var fromRemote = remoteEvents.makeAsyncIterator()

        let remoteSaw = await fromRemote.next()
        guard case .connected(let teleprompterName) = remoteSaw else {
            Issue.record("The remote reported \(String(describing: remoteSaw))")
            return
        }
        #expect(teleprompterName == "Teleprompter")
        let hostSaw = await fromHost.next()
        guard case .connected(let remoteName) = hostSaw else {
            Issue.record("The teleprompter reported \(String(describing: hostSaw))")
            return
        }
        #expect(remoteName == "Remote")

        remote.send(.command(.togglePlay))
        let command = await fromHost.next()
        guard case .received(let message) = command else {
            Issue.record("The teleprompter reported \(String(describing: command))")
            return
        }
        #expect(message == .command(.togglePlay))

        host.send(.status(.idle))
        let status = await fromRemote.next()
        guard case .received(let reply) = status else {
            Issue.record("The remote reported \(String(describing: status))")
            return
        }
        #expect(reply == .status(.idle))
    }
}
