//
//  StubUltraClient.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Ultra for UI tests (`-uiTestUltra`): no Firebase, no network, a predictable draft and polish. `-uiTestUltraReviewFails` makes the polish fail
/// (the draft is never passed off as the script) and `-uiTestUltraSlow` holds each call for two seconds (Stop and Cancel between the calls).
@MainActor
final class StubUltraClient: UltraModelClient {
    let reviewFails: Bool
    let delay: Duration
    /// What was asked, in order: what the tests read back.
    private(set) var requests: [UltraStageRequest] = []

    init(reviewFails: Bool = false, delay: Duration = .zero) {
        self.reviewFails = reviewFails
        self.delay = delay
    }

    static let draftText = "Ultra draft paragraph one, with a reason and an example.\n\nUltra draft paragraph two, with the consequence."
    static let scriptText = "Ultra polished opening, with a reason and an example.\n\nUltra polished closing, with the consequence that follows."
    static let title = "Ultra stub script"

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        requests.append(request)
        if delay > .zero { try await Task.sleep(for: delay) }
        switch request.stage {
        case .draft:
            progress(ReadTime.wordCount(in: Self.draftText))
            return UltraModelReply(text: Self.draftText, finishedNormally: true)
        case .check:
            let reply = ["script": Self.draftText, "corrections": [String]()] as [String: Any]
            let data = try JSONSerialization.data(withJSONObject: reply)
            return UltraModelReply(text: String(bytes: data, encoding: .utf8) ?? "", finishedNormally: true)
        case .review:
            if reviewFails { throw UltraClientError(failure: .provider) }
            let reply = ["title": Self.title, "script": Self.scriptText, "changes": ["Tightened the opening."]] as [String: Any]
            let data = try JSONSerialization.data(withJSONObject: reply)
            return UltraModelReply(text: String(bytes: data, encoding: .utf8) ?? "", finishedNormally: true)
        }
    }
}
#endif
