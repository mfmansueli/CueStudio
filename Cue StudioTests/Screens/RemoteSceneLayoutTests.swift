//
//  RemoteSceneLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// Settings › Remote's scene: where the devices stand at each stage, the link meeting them, and the timing curves.
@Suite("Remote scene")
struct RemoteSceneLayoutTests {
    private let width: CGFloat = 358

    @Test func apartTheTeleprompterIsLeftAndBiggerAndTheRemoteRightAndLower() {
        let apart = RemoteSceneLayout.layout(for: .apart, width: width)
        #expect(apart.prompter.center.x < width / 2 && apart.remote.center.x > width / 2)
        #expect(apart.prompter.width > apart.remote.width)
        #expect(apart.remote.center.y > apart.prompter.center.y)
        #expect(apart.code == 0)
    }

    /// Pairing: the teleprompter in the middle, bigger, showing the code, the remote gone; every device stays inside the scene.
    @Test func pairingCentresTheTeleprompterAndSendsTheRemoteAway() {
        let pairing = RemoteSceneLayout.layout(for: .pairing, width: width)
        #expect(pairing.prompter.center.x == width / 2)
        #expect(pairing.code == 1 && pairing.remote.opacity == 0)
        for stage in [RemoteStage.apart, .pairing, .linked] {
            let device = RemoteSceneLayout.layout(for: stage, width: width).prompter
            #expect(device.center.y - device.height / 2 >= 0 && device.center.y + device.height / 2 <= RemoteSceneLayout.sceneHeight)
        }
    }

    /// The link starts at the remote, ends at the teleprompter and rises above both ends in the middle.
    @Test func theLinkRunsFromTheRemoteToTheTeleprompterOverTheGap() {
        let linked = RemoteSceneLayout.layout(for: .linked, width: width)
        let start = linked.linkPoint(at: 0)
        let end = linked.linkPoint(at: 1)
        let middle = linked.linkPoint(at: 0.5)
        #expect(start.x < linked.remote.center.x && end.x > linked.prompter.center.x)
        #expect(middle.y < min(start.y, end.y))
        #expect(linked.linkPoint(at: -1) == start && linked.linkPoint(at: 2) == end)
    }

    @Test func halfWayIsBetweenTheTwoStages() {
        let apart = RemoteSceneLayout.layout(for: .apart, width: width)
        let pairing = RemoteSceneLayout.layout(for: .pairing, width: width)
        let half = apart.interpolated(to: pairing, progress: 0.5)
        #expect(half.prompter.width == (apart.prompter.width + pairing.prompter.width) / 2)
        #expect(half.code == 0.5)
        #expect(apart.interpolated(to: pairing, progress: 1) == pairing)
    }

    /// The glide settles without passing its place; the pop passes it and comes back; light's curve ends where it should.
    @Test func theCurvesStartAtZeroAndSettleAtOne() {
        #expect(RemoteSceneLayout.settle(0) == 0 && RemoteSceneLayout.settle(-1) == 0)
        #expect(RemoteSceneLayout.settle(0.75) > 0.99)
        #expect(stride(from: 0.0, through: 2, by: 0.05).allSatisfy { RemoteSceneLayout.settle($0) <= 1 })
        #expect(stride(from: 0.0, through: 1, by: 0.02).contains { RemoteSceneLayout.pop($0) > 1 })
        #expect(abs(RemoteSceneLayout.pop(2) - 1) < 0.001)
        #expect(RemoteSceneLayout.ease(0.6, over: 0.6) == 1 && RemoteSceneLayout.ease(-1, over: 0.6) == 0)
    }

    /// The code holds still enough to scan: the teleprompter floats less while it shows it.
    @Test func theTeleprompterFloatsLessWhileItShowsTheCode() {
        let quarter = RemoteSceneLayout.floatPeriod / 4
        let apart = RemoteSceneLayout.layout(for: .apart, width: width)
        let pairing = RemoteSceneLayout.layout(for: .pairing, width: width)
        let apartReach = apart.floating(at: quarter).prompter.center.y - apart.prompter.center.y
        let pairingReach = pairing.floating(at: quarter).prompter.center.y - pairing.prompter.center.y
        #expect(abs(pairingReach) < abs(apartReach))
    }

    @MainActor
    @Test func theStageFollowsTheConnection() {
        #expect(RemoteStage(role: nil, state: .off) == .apart)
        #expect(RemoteStage(role: .teleprompter, state: .waiting) == .pairing)
        #expect(RemoteStage(role: .teleprompter, state: .connected(deviceName: "iPad")) == .linked)
        #expect(RemoteStage(role: .remote, state: .searching) == .apart)
        #expect(RemoteStage(role: .remote, state: .connected(deviceName: "iPhone")) == .linked)
        #expect(RemoteStage(role: .teleprompter, state: .failed("No network")) == .apart)
    }
}
