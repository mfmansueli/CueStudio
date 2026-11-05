//
//  FakeUltraModelClient.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Cue's server's place in the tests: no network, each stage's answer set by the test, every request kept, a hook that runs while a call is out
/// (to revoke the permission or cancel between the calls), and the count the server would give (`UltraAllowanceReporting`).
@MainActor
final class FakeUltraModelClient: UltraModelClient, UltraAllowanceReporting {
    var draft: Result<UltraModelReply, any Error> = .success(UltraModelReply(text: "A developed draft with a reason and an example.", finishedNormally: true))
    var review: Result<UltraModelReply, any Error> = .success(
        UltraModelReply(text: #"{"title":"Polished title","script":"The polished script.","changes":["Tightened the opening."]}"#, finishedNormally: true)
    )
    var check: Result<UltraModelReply, any Error> = .success(UltraModelReply(
        text: #"{"script":"A checked draft with a reason and an example.","corrections":["A universal rule now says when it applies."]}"#,
        finishedNormally: true
    ))
    var fit: Result<UltraModelReply, any Error> = .success(UltraModelReply(text: #"{"script":"The fitted script."}"#, finishedNormally: true))
    /// Runs inside each call, before it answers.
    var whileCalling: ((UltraStageRequest.Stage) -> Void)?
    private(set) var requests: [UltraStageRequest] = []
    /// How many times the service made this client (it is made only for a permitted script).
    private(set) var madeCount = 0
    /// What the server says is left; nil answers as a server that can't be reached.
    var serverAllowance: UltraServerAllowance?
    /// Who each question about the count was for.
    private(set) var allowanceCallers: [UltraCaller] = []

    func made() -> Self {
        madeCount += 1
        return self
    }

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        requests.append(request)
        whileCalling?(request.stage)
        let answer: Result<UltraModelReply, any Error> = switch request.stage {
        case .draft: draft
        case .check: check
        case .review: review
        case .fit: fit
        // The library is written by a developer tool, never through the service.
        case .ideas: .failure(UltraClientError(failure: .provider))
        }
        let reply = try answer.get()
        progress(ReadTime.wordCount(in: reply.text))
        return reply
    }

    func allowance(for caller: UltraCaller) async throws -> UltraServerAllowance {
        allowanceCallers.append(caller)
        guard let serverAllowance else { throw UltraClientError(failure: .unreachable) }
        return serverAllowance
    }
}
